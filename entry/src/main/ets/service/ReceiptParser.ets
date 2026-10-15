/**
 * 购物小票识别：
 * 优先走系统视觉能力（CoreVisionKit 文字识别）提取小票文本；
 * 再用规则解析「品名 + 数量/重量 + 单价/金额」形成采购入库清单。
 */
import { image } from '@kit.ImageKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import textRecognition from '@hms.ai.ocr.textRecognition';
import { lookupFood } from './NutritionDB';
import { StockItem } from '../model/Models';

export class ReceiptParser {
  /** 小票噪音行关键词：店头信息、金额栏头、结算/售后说明等，命中即整行跳过 */
  private static readonly NOISE: RegExp =
    /(凭本|小票|发票|退货|换货|超市|卖场|便利店|分店|总部|门店|收银|机号|会员|积分|电话|地址|欢迎|光临|合计|小计|实收|应收|找零|收款|支付|优惠|折扣|满减|抹零|单号|流水|日期|时间|单价|数量|金额|品名|条码|称重|促销|特惠|营业|编号|店名|本店|客服|热线|质监)/;

  /** 全角→半角、去零宽字符（OCR 常输出全角数字/标点，会把数字匹配打空） */
  static normalizeText(text: string): string {
    let out: string = '';
    for (let i = 0; i < text.length; i++) {
      let c: number = text.charCodeAt(i);
      if (c === 0x3000) {
        out += ' ';
        continue;
      }
      if (c >= 0xFF01 && c <= 0xFF5E) {
        out += String.fromCharCode(c - 0xFEE0);
        continue;
      }
      const ch: string = text.charAt(i);
      if (ch === '\u200b' || ch === '\ufeff') {
        continue;
      }
      out += ch;
    }
    return out;
  }

  /** 从小票文本解析库存条目 */
  static parseText(text: string): StockItem[] {
    const items: StockItem[] = [];
    const seen: Set<string> = new Set<string>();
    const lines: string[] = ReceiptParser.normalizeText(text).split(/\r?\n/);
    for (const raw of lines) {
      const line: string = raw.trim();
      if (line.length < 2) {
        continue;
      }
      // 店头/栏头/结算说明等噪音行
      if (ReceiptParser.NOISE.test(line)) {
        continue;
      }
      // 无数字的行（店名、栏头「单价 数量」等）不是食材行
      if (!/\d/.test(line)) {
        continue;
      }
      // 品名 = 行内最长的非噪音中文串（OCR 可能丢空格/换行错位，品名不一定在行首）
      const runs: RegExpMatchArray | null = line.match(/[\u4e00-\u9fa5][\u4e00-\u9fa5A-Za-z]{1,11}/g);
      if (runs === null) {
        continue;
      }
      let name: string = '';
      for (const r of runs) {
        if (ReceiptParser.NOISE.test(r)) {
          continue;
        }
        if (r.length > name.length) {
          name = r;
        }
      }
      if (name.length < 2) {
        continue;
      }

      let amount: number = 0;
      let unit: string = '份';
      // ① 带重量单位的数字：西红柿 1.25kg / 土豆 2斤 / 排骨 500g（OCR 丢空格时「1.25kg9.90」也要能命中）
      const wm: RegExpMatchArray | null =
        line.match(/(?<![A-Za-z0-9.])(\d+(?:\.\d+)?)\s*(kg|KG|Kg|千克|克|g|斤|两)(?![A-Za-z])/);
      if (wm !== null) {
        const v: number = parseFloat(wm[1]);
        const u: string = wm[2];
        if (u === 'kg' || u === 'KG' || u === 'Kg' || u === '千克') {
          amount = Math.round(v * 1000);
        } else if (u === '斤') {
          amount = Math.round(v * 500);
        } else if (u === '两') {
          amount = Math.round(v * 50);
        } else {
          amount = Math.round(v);
        }
        unit = '克';
      } else {
        // ② 计数单位：鸡蛋 2盒25.6（丢空格）/ 啤酒 6瓶 / 鸡蛋 1份；以及 ×N 形式（土豆×3）
        const xm: RegExpMatchArray | null = line.match(/[xX×]\s*(\d{1,2})(?!\d)/);
        const cm: RegExpMatchArray | null = xm !== null ? null
          : line.match(/(?<![A-Za-z0-9.])(\d+(?:\.\d+)?)\s*(个|盒|袋|包|瓶|罐|桶|把|根|只|条|块|颗|粒|支|枚|份)(?![\u4e00-\u9fa5A-Za-z])/);
        if (xm !== null) {
          amount = parseInt(xm[1], 10);
          unit = '份';
        } else if (cm !== null) {
          amount = Math.round(parseFloat(cm[1]));
          unit = cm[2];
        } else {
          // ③ 裸数字（常见称重小票：散西红柿 1.256 9.96 12.51 / 西红柿 6901234567890 1.256 12.51）
          // 有效重量 = 第一个 0<x≤50 的小数；有效件数 = 第一个 1≤n≤99 的整数（条码大整数直接跳过）
          const nums: string[] = line.match(/\d+(?:\.\d+)?/g) ?? [];
          let kg: number = 0;
          let count: number = 0;
          for (const n of nums) {
            if (n.indexOf('.') >= 0) {
              const v: number = parseFloat(n);
              if (v > 0 && v <= 50) {
                kg = v;
                break;
              }
            }
          }
          if (kg > 0) {
            amount = Math.round(kg * 1000);
            unit = '克';
          } else {
            for (const n of nums) {
              if (n.indexOf('.') < 0) {
                const v: number = parseInt(n, 10);
                if (v >= 1 && v <= 99) {
                  count = v;
                  break;
                }
              }
            }
            if (count > 0) {
              amount = count;
              unit = '份';
            }
          }
        }
      }
      if (amount <= 0) {
        continue;
      }
      // 同名同量去重（OCR 重复行）
      const key: string = `${name}_${unit}_${amount}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);

      const info = lookupFood(name);
      const it: StockItem = new StockItem();
      it.id = `s${Date.now()}_${items.length}`;
      it.name = name;
      it.amount = amount;
      it.unit = unit;
      it.category = info !== null ? info.category : '其他';
      it.buyDate = Date.now();
      it.baseShelfDays = info !== null ? info.shelfDays : 7;
      items.push(it);
    }
    return items;
  }

  /** 系统文字识别引擎是否已初始化（幂等，进程内只 init 一次） */
  private static ocrInited: boolean = false;

  /**
   * 选一张小票照片并用系统识别能力（Core Vision Kit 文字识别）提取文本。
   * 文件统一走 fd 打开（media 库 URI 直接 createImageSource 可能失败）；
   * 失败时抛出异常，由页面 toast 展示原始原因。
   */
  static async scanReceipt(): Promise<string> {
    const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
    const result: picker.PhotoSelectResult = await photoPicker.select({
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (result.photoUris.length === 0) {
      return '';
    }
    const uri: string = result.photoUris[0];
    const file: fileIo.File = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    let fileSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    try {
      fileSource = await image.createImageSource(file.fd);
      pixelMap = await fileSource.createPixelMap();
      if (!ReceiptParser.ocrInited) {
        await textRecognition.init();
        ReceiptParser.ocrInited = true;
      }
      const info: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const data: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(info);
      return data.value;
    } finally {
      if (pixelMap !== null) {
        pixelMap.release();
      }
      if (fileSource !== null) {
        fileSource.release();
      }
      try {
        fileIo.closeSync(file);
      } catch (e) {
      }
    }
  }
}
