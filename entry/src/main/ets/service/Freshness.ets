/**
 * 剩余食材新鲜度估算：
 * 依据 采购日期 + 当日日期 + 气候状况（季节/温度代理）估计剩余可存时间。
 * 气候：夏季高温（6~8月）加速变质 ×1.5；冬季（12~2月）×0.7；其余 ×1.0。
 */
import { lookupFood } from './NutritionDB';
import { DataStore } from './DataStore';
import { FreshLevel, StockItem } from '../model/Models';

export class Freshness {
  /** 气候系数 */
  static climateFactor(now: Date): number {
    const m: number = now.getMonth() + 1;
    if (m >= 6 && m <= 8) {
      return 1.5;
    }
    if (m === 12 || m <= 2) {
      return 0.7;
    }
    return 1.0;
  }

  /** 已变质比例（0~1） */
  static decayRatio(item: StockItem, now: Date): number {
    const days: number = Math.max(0, (now.getTime() - item.buyDate) / 86400000);
    const shelf: number = Math.max(1, item.baseShelfDays * Freshness.climateFactor(now));
    return Math.min(1, days / shelf);
  }

  static level(ratio: number): FreshLevel {
    if (ratio >= 0.9) {
      return FreshLevel.CHECK;
    }
    if (ratio >= 0.6) {
      return FreshLevel.SOON;
    }
    return FreshLevel.FRESH;
  }

  static levelText(lv: FreshLevel): string {
    if (lv === FreshLevel.FRESH) {
      return '新鲜';
    }
    if (lv === FreshLevel.SOON) {
      return '建议尽快食用';
    }
    return '建议评估是否丢弃';
  }

  static levelColor(lv: FreshLevel): Resource {
    if (lv === FreshLevel.FRESH) {
      return $r('app.color.tag_green');
    }
    if (lv === FreshLevel.SOON) {
      return $r('app.color.tag_orange');
    }
    return $r('app.color.tag_red');
  }

  /** 剩余可存天数（向下取整，0 表示当天内） */
  static remainDays(item: StockItem, now: Date): number {
    const ratio: number = Freshness.decayRatio(item, now);
    if (ratio >= 1) {
      return 0;
    }
    const shelf: number = Math.max(1, item.baseShelfDays * Freshness.climateFactor(now));
    return Math.floor((1 - ratio) * shelf);
  }

  /** 刷新整个库存的状态（按新鲜度升序：最急的排前） */
  static snapshot(): StockItem[] {
    const now: Date = new Date();
    const list: StockItem[] = DataStore.getStock().slice();
    list.sort((a: StockItem, b: StockItem): number =>
      Freshness.decayRatio(b, now) - Freshness.decayRatio(a, now));
    return list;
  }
}
