/**
 * 剩余食材新鲜度估算：
 * 依据 采购日期 + 当日日期 + 气候状况（实时气温，失败回退季节/温度代理）
 * + 储存状态（常温/冷藏/冷冻修正）估计剩余可存时间。
 * 基准保鲜期为冷藏口径；常温折半，冷冻按类目倍率延长。
 */
import { lookupFood } from './NutritionDB';
import { DataStore } from './DataStore';
import { Weather } from './Weather';
import { FreshLevel, StockItem } from '../model/Models';

/** 冷冻倍率（相对冷藏基准）：肉禽/水产/主食冻得久，叶菜冻损大 */
const FROZEN_FACTOR: Map<string, number> = new Map<string, number>([
  ['肉类', 8], ['水产', 8], ['主食', 6], ['蛋类', 4], ['豆制品', 2], ['叶菜', 1.5]
]);
const FROZEN_DEFAULT: number = 3;

export class Freshness {
  /** 储存状态修正系数：常温 0.5 / 冷藏 1.0 / 冷冻按类目倍率 */
  static storageFactor(item: StockItem): number {
    if (item.storage === '常温') {
      return 0.5;
    }
    if (item.storage === '冷冻') {
      return FROZEN_FACTOR.get(item.category) ?? FROZEN_DEFAULT;
    }
    return 1.0;
  }

  /** 气候系数（优先实时气温，失败回退月份代理） */
  static async climateFactor(now: Date): Promise<number> {
    return Weather.climateFactor(now);
  }

  /** 月份代理（向后兼容保留） */
  static monthFactor(now: Date): number {
    return Weather.monthFactor(now);
  }

  /** 有效保鲜天数（异步）= 基准 × 气候 × 储存 */
  private static async shelfDays(item: StockItem, now: Date): Promise<number> {
    const factor: number = await Weather.climateFactor(now);
    return Math.max(0.5, item.baseShelfDays * factor * Freshness.storageFactor(item));
  }

  /** 已变质比例（同步核心：气候系数由调用方给定，UI/列表刷新走这里） */
  static decayRatioSync(item: StockItem, now: Date, climate: number): number {
    const days: number = Math.max(0, (now.getTime() - item.buyDate) / 86400000);
    const shelf: number = Math.max(0.5, item.baseShelfDays * climate * Freshness.storageFactor(item));
    return Math.min(1, days / shelf);
  }

  /** 已变质比例（异步：气候系数实时取气温/月份代理） */
  static async decayRatio(item: StockItem, now: Date): Promise<number> {
    const climate: number = await Weather.climateFactor(now);
    return Freshness.decayRatioSync(item, now, climate);
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

  /** 剩余可存天数（同步核心，向下取整，0 表示当天内） */
  static remainDaysSync(item: StockItem, now: Date, climate: number): number {
    const ratio: number = Freshness.decayRatioSync(item, now, climate);
    if (ratio >= 1) {
      return 0;
    }
    const shelf: number = Math.max(0.5, item.baseShelfDays * climate * Freshness.storageFactor(item));
    return Math.floor((1 - ratio) * shelf);
  }

  /** 剩余可存天数（异步：气候系数实时取） */
  static async remainDays(item: StockItem, now: Date): Promise<number> {
    const climate: number = await Weather.climateFactor(now);
    return Freshness.remainDaysSync(item, now, climate);
  }

  /** 库存快照（按新鲜度升序：最急的排前；气候系数由调用方给定） */
  static snapshotWith(climate: number): StockItem[] {
    const now: Date = new Date();
    const list: StockItem[] = DataStore.getStock().slice();
    list.sort((a: StockItem, b: StockItem): number =>
      Freshness.decayRatioSync(b, now, climate) - Freshness.decayRatioSync(a, now, climate));
    return list;
  }
}
