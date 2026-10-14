/**
 * 购物小票识别：
 * 优先走系统视觉能力（CoreVisionKit 文字识别）提取小票文本；
 * 再用规则解析「品名 + 数量/重量 + 单价/金额」形成采购入库清单。
 */
import { image } from '@kit.ImageKit';
import { picker } from '@kit.CoreFileKit';
import textRecognition from '@hms.ai.ocr.textRecognition';
import { lookupFood } from './NutritionDB';
import { StockItem } from '../model/Models';

export class ReceiptParser {
  /** 从小票文本解析库存条目 */
  static parseText(text: string): StockItem[] {
    const items: StockItem[] = [];
    const lines: string[] = text.split(/\r?\n/);
    for (const raw of lines) {
      const line: string = raw.trim();
      if (line.length < 2) {
        continue;
      }
      // 常见小票行：西红柿 1.25kg 9.90 / 土豆 2斤 6.00 / 鸡蛋 1份 12.9
      const m: RegExpMatchArray | null = line.match(
        /([\u4e00-\u9fa5A-Za-z]{2,10})\s*(\d+(?:\.\d+)?)\s*(kg|KG|千克|g|克|斤|两|份|个|盒|袋|包)?/);
      if (m === null) {
        continue;
      }
      const name: string = m[1];
      let amount: number = parseFloat(m[2]);
      const unit: string = m[3] ?? '份';
      if (unit === 'kg' || unit === 'KG' || unit === '千克') {
        amount = Math.round(amount * 1000);
      } else if (unit === '斤') {
        amount = Math.round(amount * 500);
      } else if (unit === '两') {
        amount = Math.round(amount * 50);
      } else if (unit !== 'g' && unit !== '克') {
        amount = Math.round(amount);
      }
      const info = lookupFood(name);
      const it: StockItem = new StockItem();
      it.id = `s${Date.now()}_${items.length}`;
      it.name = name;
      it.amount = (unit === 'kg' || unit === 'KG' || unit === '千克' || unit === '斤' || unit === '两' || unit === 'g' || unit === '克')
        ? amount : 1;
      it.unit = (unit === 'kg' || unit === 'KG' || unit === '千克' || unit === '斤' || unit === '两' || unit === 'g' || unit === '克')
        ? '克' : unit;
      it.category = info !== null ? info.category : '其他';
      it.buyDate = Date.now();
      it.baseShelfDays = info !== null ? info.shelfDays : 7;
      items.push(it);
    }
    return items;
  }

  /** 选一张小票照片并识别文本；失败返回空串 */
  static async scanReceipt(): Promise<string> {
    const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
    const result: picker.PhotoSelectResult = await photoPicker.select({
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (result.photoUris.length === 0) {
      return '';
    }
    const fileSource = await image.createImageSource(result.photoUris[0]);
    const pixelMap = await fileSource.createPixelMap();
    const info: textRecognition.VisionInfo = { pixelMap: pixelMap };
    const data: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(info);
    pixelMap.release();
    fileSource.release();
    return data.value;
  }
}
