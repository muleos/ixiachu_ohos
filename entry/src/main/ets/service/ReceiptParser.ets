/**
 * 购物小票识别：
 * 优先走系统视觉能力（CoreVisionKit 文字识别）提取小票文本；
 * 再用规则解析「品名 + 数量/重量 + 单价/金额」形成采购入库清单。
 * 品名经别名表归一（番茄→西红柿），金额折算单价入库（元/kg 或 元/件）。
 */
import { image } from '@kit.ImageKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import textRecognition from '@hms.ai.ocr.textRecognition';
import { lookupFood } from './NutritionDB';
import { StockItem } from '../model/Models';
import { DataStore } from './DataStore';

const TAG: string = 'ReceiptParser';
const DOMAIN: number = 0x1CA;

/** 解码上限：宽 ≤1080 且高 ≤1920（小票为竖长图，宽高双限流内存峰值） */
const DEC_CAP_W: number = 1080;
const DEC_CAP_H: number = 1920;

function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, ms);
  });
}

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

  /** 从小票文本解析库存条目（防御：异常兜底为空结果并记日志，绝不让页面闪退） */
  static parseText(text: string): StockItem[] {
    try {
      return ReceiptParser.doParseText(text);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parseText crashed: %{public}s', (e as Error).message ?? '');
      return [];
    }
  }

  private static doParseText(text: string): StockItem[] {
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
      // 已命中的数量表达式/数字 token（金额解析前从行内剔除，避免金额与数量混淆）
      let kgToken: string = '';
      let countToken: string = '';
      let xm: RegExpMatchArray | null = null;
      let cm: RegExpMatchArray | null = null;
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
        xm = line.match(/[xX×]\s*(\d{1,2})(?!\d)/);
        cm = xm !== null ? null
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
                kgToken = n;
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
                  countToken = n;
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

      // ④ 金额/单价：剔除已匹配的数量部分后，剩余行里找 ¥x.xx / x.xx元 / 末位数字
      let rem: string = line;
      if (wm !== null) {
        rem = rem.replace(wm[0], '');
      } else if (xm !== null) {
        rem = rem.replace(xm[0], '');
      } else if (cm !== null) {
        rem = rem.replace(cm[0], '');
      } else if (kgToken.length > 0) {
        rem = rem.replace(kgToken, '');
      } else if (countToken.length > 0) {
        rem = rem.replace(countToken, '');
      }
      let price: number = 0;
      const pm: RegExpMatchArray | null = rem.match(/(?:¥|￥)\s*(\d+(?:\.\d+)?)/);
      const pm2: RegExpMatchArray | null = pm !== null ? null : rem.match(/(\d+(?:\.\d+)?)\s*(?:元|块)/);
      if (pm !== null) {
        price = parseFloat(pm[1]);
      } else if (pm2 !== null) {
        price = parseFloat(pm2[1]);
      } else {
        const nums2: string[] = rem.match(/\d+(?:\.\d+)?/g) ?? [];
        // 金额 = 末位 0.1≤x≤9999 的数字（条码大整数天然落在范围外）
        for (let i = nums2.length - 1; i >= 0; i--) {
          const v: number = parseFloat(nums2[i]);
          if (v >= 0.1 && v <= 9999) {
            price = v;
            break;
          }
        }
      }

      // 品名归一（别名表：番茄→西红柿），归一后再查知识库
      name = DataStore.normalizeName(name);

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
      // 单价折算：重量类元/千克，计数类元/件（异常值丢弃，确认页可见）
      if (price > 0) {
        it.lastPriceDate = ReceiptParser.todayStr();
        if (unit === '克') {
          const ppk: number = Math.round(price / (amount / 1000) * 100) / 100;
          if (ppk >= 0.1 && ppk <= 9999) {
            it.pricePerKg = ppk;
          } else {
            it.lastPriceDate = '';
          }
        } else {
          const ppu: number = Math.round(price / amount * 100) / 100;
          if (ppu >= 0.1 && ppu <= 9999) {
            it.pricePerUnit = ppu;
          } else {
            it.lastPriceDate = '';
          }
        }
      }
      items.push(it);
    }
    return items;
  }

  /** 系统文字识别引擎是否已初始化（幂等，进程内只 init 一次） */
  private static ocrInited: boolean = false;

  static todayStr(): string {
    const d: Date = new Date();
    const m: string = String(d.getMonth() + 1).padStart(2, '0');
    const day: string = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}`;
  }

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
    const file: fileIo.File = await fileIo.open(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
    try {
      return await ReceiptParser.recognizeFd(file.fd);
    } finally {
      try {
        fileIo.closeSync(file);
      } catch (e) {
      }
    }
  }

  /**
   * 拉起系统相机拍小票（Want imageCapture，零权限）。
   * 拍成返回照片路径，用户取消/失败返回空串。
   * v1.9.0：返回后轮询校验「文件存在 + 体积稳定 + JPEG 魔数」，
   * 系统相机落盘慢/半截文件直接进解码器是部分机型闪退根因。
   */
  static async captureReceipt(context: common.UIAbilityContext): Promise<string> {
    const path: string = `${context.cacheDir}/receipt_${Date.now()}.jpg`;
    const want: Want = {
      action: 'ohos.want.action.imageCapture',
      parameters: { outputPath: path }
    };
    const result: common.AbilityResult = await context.startAbilityForResult(want);
    if (result.resultCode !== 0) {
      return '';
    }
    // 落盘校验：最长等 2.4s，要求 JPEG 魔数(FF D8) 且体积两次采样一致（写完不再增长）
    let lastSize: number = -1;
    for (let i = 0; i < 8; i++) {
      await sleepMs(300);
      let size: number = 0;
      try {
        const st: fileIo.Stat = fileIo.statSync(path);
        size = st.size;
      } catch (e) {
        continue; // 文件尚未创建
      }
      if (size > 2048 && size === lastSize && await ReceiptParser.isJpeg(path)) {
        hilog.info(DOMAIN, TAG, 'capture ok size=%{public}d waits=%{public}d', size, i);
        return path;
      }
      lastSize = size;
    }
    hilog.error(DOMAIN, TAG, 'capture file invalid or not settled');
    return '';
  }

  /** 校验文件头是否为 JPEG（FF D8 FF），半截/写坏文件不进解码器 */
  private static async isJpeg(path: string): Promise<boolean> {
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const buf: ArrayBuffer = new ArrayBuffer(3);
      const readLen: number = fileIo.readSync(file.fd, buf);
      if (readLen < 3) {
        return false;
      }
      const bytes: Uint8Array = new Uint8Array(buf);
      return bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF;
    } catch (e) {
      return false;
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (e) {
        }
      }
    }
  }

  /** 从本地照片文件识别文本（拍照产物），链路与相册一致 */
  static async recognizeFromPath(path: string): Promise<string> {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      return await ReceiptParser.recognizeFd(file.fd);
    } finally {
      try {
        fileIo.closeSync(file);
      } catch (e) {
      }
    }
  }

  /**
   * fd → （解码期限流降采样）→ OCR 文本。
   * v1.9.0 加固：
   * 1. 宽高双限流（≤1080×1920，取更严的等比系数）——此前只限宽，竖长小票高度无上限，
   *    4:3 竖拍 3000×4000 降采样后仍 1080×1440 尚可，但 9:16 全屏竖拍 3000×5333 会得到
   *    1080×1920 之上的峰值内存，部分机型在解码/OCR 原生层崩溃；
   * 2. 解码失败自动降一档（720 宽）重试，而不是把原生异常抛给用户；
   * 3. getImageInfo 失败不再中断（直接按上限解码）；
   * 4. 全程 hilog 埋点，真机闪退可从日志定位到具体步骤。
   */
  private static async recognizeFd(fd: number): Promise<string> {
    let fileSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    try {
      hilog.info(DOMAIN, TAG, 'recognizeFd begin fd=%{public}d', fd);
      fileSource = await image.createImageSource(fd);
      let w: number = 0;
      let h: number = 0;
      try {
        const srcInfo: image.ImageInfo = await fileSource.getImageInfo();
        w = srcInfo.size.width;
        h = srcInfo.size.height;
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'getImageInfo failed, decode with cap only');
      }
      // 候选降采样档位：先按原图算最严系数，失败降一档
      const caps: number[][] = ReceiptParser.decodeSizes(w, h);
      for (let i = 0; i < caps.length; i++) {
        const opts: image.DecodingOptions = { desiredSize: { width: caps[i][0], height: caps[i][1] } };
        try {
          pixelMap = await fileSource.createPixelMap(opts);
          hilog.info(DOMAIN, TAG, 'decoded %{public}dx%{public}d -> %{public}dx%{public}d (tier %{public}d)',
            w, h, caps[i][0], caps[i][1], i);
          break;
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'createPixelMap tier %{public}d failed: %{public}s', i, (e as Error).message);
          pixelMap = null;
        }
      }
      if (pixelMap === null) {
        throw new Error('图片解码失败，请重拍或换相册图片');
      }
      if (!ReceiptParser.ocrInited) {
        await textRecognition.init();
        ReceiptParser.ocrInited = true;
      }
      const info: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const data: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(info);
      hilog.info(DOMAIN, TAG, 'ocr ok len=%{public}d', data.value.length);
      return data.value;
    } finally {
      if (pixelMap !== null) {
        try {
          pixelMap.release();
        } catch (e) {
        }
      }
      if (fileSource !== null) {
        try {
          fileSource.release();
        } catch (e) {
        }
      }
    }
  }

  /** 解码尺寸档位：把原图等比塞进 (1080×1920) 再塞进 (720×1280)；无原图信息时按上限直出 */
  private static decodeSizes(w: number, h: number): number[][] {
    const tiers: number[][] = [];
    const fits: number[][] = [[DEC_CAP_W, DEC_CAP_H], [720, 1280]];
    for (const cap of fits) {
      if (w <= 0 || h <= 0) {
        tiers.push([cap[0], Math.round(cap[0] * 4 / 3)]); // 无尺寸信息按 4:3 估
        continue;
      }
      const scale: number = Math.min(cap[0] / w, cap[1] / h, 1);
      tiers.push([Math.max(1, Math.round(w * scale)), Math.max(1, Math.round(h * scale))]);
    }
    return tiers;
  }
}
