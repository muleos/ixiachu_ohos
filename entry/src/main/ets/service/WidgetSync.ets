/**
 * 桌面卡片数据桥：
 * 组装「今日菜单 + 临期食材」的 FormBindingData，管理已添加卡片的 formId，
 * 业务变更点（菜单确认/库存变更）调 updateAll() 主动推送到所有卡片。
 * 兜底：form_config 配置 30 分钟定时刷新 + 每日 07:30 定点刷新。
 */
import { formBindingData, formProvider } from '@kit.FormKit';
import { DataStore } from './DataStore';
import { Freshness } from './Freshness';
import { DailyMenu, FreshLevel, StockItem } from '../model/Models';

const FORM_IDS_KEY: string = 'widget_form_ids';
const MAX_DISHES: number = 3;
const MAX_URGENT: number = 3;

export class WidgetSync {
  /** 已添加卡片 id 列表（onAddForm 累积 / onRemoveForm 移除） */
  static formIds(): string[] {
    const raw: string = DataStore.getSetting(FORM_IDS_KEY);
    if (raw.length === 0) {
      return [];
    }
    try {
      return JSON.parse(raw) as string[];
    } catch (e) {
      return [];
    }
  }

  static addFormId(id: string): void {
    if (id.length === 0 || WidgetSync.formIds().indexOf(id) >= 0) {
      return;
    }
    const list: string[] = WidgetSync.formIds();
    list.push(id);
    DataStore.setSetting(FORM_IDS_KEY, JSON.stringify(list));
  }

  static removeFormId(id: string): void {
    const list: string[] = WidgetSync.formIds().filter((f: string): boolean => f !== id);
    DataStore.setSetting(FORM_IDS_KEY, JSON.stringify(list));
  }

  /** 组装卡片数据：最近一次确认的菜单（无确认则最近生成），临期 Top3（月份代理口径） */
  static buildBindingData(): formBindingData.FormBindingData {
    const menus = DataStore.getMenus();
    let latest: DailyMenu | null = null;
    for (let i = menus.length - 1; i >= 0; i--) {
      if (menus[i].confirmed) {
        latest = menus[i];
        break;
      }
    }
    if (latest === null && menus.length > 0) {
      latest = menus[menus.length - 1];
    }
    const dishes: string[] = latest !== null ? (latest as DailyMenu).recipeNames.slice(0, MAX_DISHES) : [];
    const people: number = latest !== null ? (latest as DailyMenu).people : 0;

    const now: Date = new Date();
    const urgent: StockItem[] = DataStore.getStock()
      .filter((s: StockItem): boolean =>
        Freshness.level(Freshness.decayRatioSync(s, now, Freshness.monthFactor(now))) >= FreshLevel.SOON)
      .sort((a: StockItem, b: StockItem): number =>
        Freshness.decayRatioSync(b, now, Freshness.monthFactor(now)) -
        Freshness.decayRatioSync(a, now, Freshness.monthFactor(now)))
      .slice(0, MAX_URGENT);
    const urgentNames: string[] = urgent.map((s: StockItem): string => s.name);

    const d: Date = new Date();
    const dateText: string = `${d.getMonth() + 1}月${d.getDate()}日`;
    return formBindingData.createFormBindingData({
      dishes: dishes,
      people: people,
      urgent: urgentNames,
      urgentCount: urgentNames.length,
      hasMenu: dishes.length > 0,
      date: dateText
    });
  }

  /** 推送所有已添加卡片；逐张容错（个别卡片更新失败不影响其余） */
  static async updateAll(): Promise<void> {
    const ids: string[] = WidgetSync.formIds();
    if (ids.length === 0) {
      return;
    }
    const data: formBindingData.FormBindingData = WidgetSync.buildBindingData();
    for (const id of ids) {
      try {
        await formProvider.updateForm(id, data);
      } catch (e) {
        // 卡片可能已被移除；失败忽略，等 onRemoveForm 清理
      }
    }
  }
}
