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

  /** 从小票文本解析库存条目 */
  static parseText(text: string): StockItem[] {
    const items: StockItem[] = [];
    const seen: Set<string> = new Set<string>();
    const lines: string[] = text.split(/\r?\n/);
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
      // 品名 = 行首的中文（可含字母）连续串，必须含中文（排除 NO.0001、日期行等）
      const nm: RegExpMatchArray | null = line.match(/^([\u4e00-\u9fa5][\u4e00-\u9fa5A-Za-z]{1,11})/);
      if (nm === null) {
        continue;
      }
      const name: string = nm[1];
      if (ReceiptParser.NOISE.test(name)) {
        continue;
      }

      let amount: number = 0;
      let unit: string = '份';
      // ① 带重量单位的数字：西红柿 1.25kg / 土豆 2斤 / 排骨 500g
      const wm: RegExpMatchArray | null =
        line.match(/(?<![A-Za-z0-9.])(\d+(?:\.\d+)?)\s*(kg|KG|Kg|千克|克|g|斤|两)(?![A-Za-z0-9])/);
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
        // ② 计数单位：鸡蛋 2盒 / 啤酒 6瓶 / 鸡蛋 1份
        const cm: RegExpMatchArray | null =
          line.match(/(?<![A-Za-z0-9.])(\d+(?:\.\d+)?)\s*(个|盒|袋|包|瓶|罐|桶|把|根|只|条|块|颗|粒|支|枚|份)(?![\u4e00-\u9fa5A-Za-z0-9])/);
        if (cm !== null) {
          amount = Math.round(parseFloat(cm[1]));
          unit = cm[2];
        } else {
          // ③ 裸数字（常见称重小票：散西红柿 1.256 9.96 12.51）
          // 第一个数字取重量（小数按 kg，整数按件数），后面的多为单价/金额
          const nums: string[] = line.match(/(?<![A-Za-z0-9.])\d+(?:\.\d+)?/g) ?? [];
          if (nums.length === 0) {
            continue;
          }
          const first: string = nums[0];
          if (first.indexOf('.') >= 0) {
            const kg: number = parseFloat(first);
            if (kg <= 0 || kg > 50) {
              continue;
            }
            amount = Math.round(kg * 1000);
            unit = '克';
          } else {
            const n: number = parseInt(first, 10);
            if (n <= 0 || n > 99) {
              continue;
            }
            amount = n;
            unit = '份';
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
