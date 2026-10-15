/** 本地数据仓库：preferences 持久化菜谱 / 点菜记录 / 采购清单 / 食材库存 / 消耗日志 */
import { preferences } from '@kit.ArkData';
import { ConsumeRecord, DailyMenu, Recipe, ShoppingItem, StockItem } from '../model/Models';
import { lookupFood } from './NutritionDB';
import { RecipeParser } from './RecipeParser';

const STORE_NAME: string = 'ixiachu_data';
const KEY_RECIPES: string = 'recipes_json';
const KEY_MENUS: string = 'menus_json';
const KEY_SHOPPING: string = 'shopping_json';
const KEY_STOCK: string = 'stock_json';
const KEY_CONSUME: string = 'consume_json';

export class DataStore {
  private static store: preferences.Preferences | null = null;
  private static recipes: Recipe[] = [];
  private static menus: DailyMenu[] = [];
  private static shopping: ShoppingItem[] = [];
  private static stock: StockItem[] = [];
  private static consumeLog: ConsumeRecord[] = [];
  /** 数据版本号：增删改后 +1，页面通过 @StorageProp 订阅刷新 */
  static rev: number = 0;

  static async init(context: Context): Promise<void> {
    if (DataStore.store !== null) {
      return;
    }
    DataStore.store = await preferences.getPreferences(context, STORE_NAME);
    DataStore.recipes = DataStore.loadRecipes();
    DataStore.menus = DataStore.loadMenus();
    DataStore.shopping = DataStore.loadShopping();
    DataStore.stock = DataStore.loadStock();
    DataStore.consumeLog = DataStore.loadConsume();
    DataStore.migrateIngredientNames();
    // 版本号 +1：让订阅 dataRev 的页面在异步初始化完成后刷新一次
    DataStore.rev += 1;
    AppStorage.setOrCreate<number>('dataRev', DataStore.rev);
    // 采购清单用专属键强广播（@StorageLink 直连，不依赖 dataRev 间接刷新）
    DataStore.publishShopping();
  }

  /**
   * 存量数据修复：旧版解析器把「盐 3克」整串当成了食材名（单字名不匹配正则）。
   * 名字里含数字的食材按原文重新解析一遍，并重算该菜谱营养估算。
   */
  private static migrateIngredientNames(): void {
    let changed: boolean = false;
    for (const r of DataStore.recipes) {
      let recipeChanged: boolean = false;
      for (const ing of r.ingredients) {
        if (/\d/.test(ing.name)) {
          const fixed = RecipeParser.ingredientFromRaw(ing.raw.length > 0 ? ing.raw : ing.name);
          if (fixed !== null && !/\d/.test(fixed.name)) {
            ing.name = fixed.name;
            ing.amount = fixed.amount;
            ing.unit = fixed.unit;
            recipeChanged = true;
          }
        }
      }
      if (recipeChanged) {
        r.nutrition = RecipeParser.estimateNutrition(r.ingredients, r.servings);
        changed = true;
      }
    }
    if (changed) {
      DataStore.persist(KEY_RECIPES, DataStore.recipes);
    }
  }

  /** 采购清单变化广播：OrderTab 生成 / ShoppingTab 勾选 / 清除已购 统一走这里 */
  private static publishShopping(): void {
    DataStore.rev += 1;
    AppStorage.setOrCreate<number>('dataRev', DataStore.rev);
    AppStorage.setOrCreate<number>('shoppingRev', DataStore.rev);
  }

  private static loadRecipes(): Recipe[] {
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(KEY_RECIPES, '') as string;
      return raw.length === 0 ? [] : JSON.parse(raw) as Recipe[];
    } catch (e) {
      return [];
    }
  }

  private static loadMenus(): DailyMenu[] {
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(KEY_MENUS, '') as string;
      const list: DailyMenu[] = raw.length === 0 ? [] : JSON.parse(raw) as DailyMenu[];
      // 存量数据补默认字段（旧版无 confirmed）
      for (const m of list) {
        if (m.confirmed === undefined || m.confirmed === null) {
          m.confirmed = false;
        }
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  private static loadShopping(): ShoppingItem[] {
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(KEY_SHOPPING, '') as string;
      return raw.length === 0 ? [] : JSON.parse(raw) as ShoppingItem[];
    } catch (e) {
      return [];
    }
  }

  private static loadStock(): StockItem[] {
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(KEY_STOCK, '') as string;
      const list: StockItem[] = raw.length === 0 ? [] : JSON.parse(raw) as StockItem[];
      // 存量数据补默认字段（旧版无 lastCalibrated）
      for (const s of list) {
        if (s.lastCalibrated === undefined || s.lastCalibrated === null) {
          s.lastCalibrated = 0;
        }
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  private static loadConsume(): ConsumeRecord[] {
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(KEY_CONSUME, '') as string;
      return raw.length === 0 ? [] : JSON.parse(raw) as ConsumeRecord[];
    } catch (e) {
      return [];
    }
  }

  private static persist(key: string, value: object): void {
    if (DataStore.store === null) {
      return;
    }
    try {
      (DataStore.store as preferences.Preferences).putSync(key, JSON.stringify(value));
      (DataStore.store as preferences.Preferences).flush();
    } catch (e) {
    }
    DataStore.rev += 1;
    AppStorage.setOrCreate<number>('dataRev', DataStore.rev);
  }

  /** 通用设置项（如 xiachufang-api 服务地址） */
  static getSetting(key: string): string {
    if (DataStore.store === null) {
      return '';
    }
    try {
      return (DataStore.store as preferences.Preferences).getSync(key, '') as string;
    } catch (e) {
      return '';
    }
  }

  static setSetting(key: string, value: string): void {
    if (DataStore.store === null) {
      return;
    }
    try {
      (DataStore.store as preferences.Preferences).putSync(key, value);
      (DataStore.store as preferences.Preferences).flush();
    } catch (e) {
    }
  }

  static getRecipes(): Recipe[] {
    return DataStore.recipes;
  }

  static getRecipe(id: string): Recipe | null {
    for (const r of DataStore.recipes) {
      if (r.id === id) {
        return r;
      }
    }
    return null;
  }

  static saveRecipe(r: Recipe): void {
    for (let i = 0; i < DataStore.recipes.length; i++) {
      if (DataStore.recipes[i].id === r.id) {
        DataStore.recipes[i] = r;
        DataStore.persist(KEY_RECIPES, DataStore.recipes);
        return;
      }
    }
    DataStore.recipes.unshift(r);
    DataStore.persist(KEY_RECIPES, DataStore.recipes);
  }

  static deleteRecipe(id: string): void {
    DataStore.recipes = DataStore.recipes.filter((r: Recipe): boolean => r.id !== id);
    DataStore.persist(KEY_RECIPES, DataStore.recipes);
  }

  static searchRecipes(keyword: string): Recipe[] {
    if (keyword.length === 0) {
      return DataStore.recipes;
    }
    return DataStore.recipes.filter((r: Recipe): boolean =>
      r.name.indexOf(keyword) >= 0 || r.tags.join(',').indexOf(keyword) >= 0);
  }

  static getMenus(): DailyMenu[] {
    return DataStore.menus;
  }

  static addMenu(m: DailyMenu): void {
    DataStore.menus.unshift(m);
    if (DataStore.menus.length > 60) {
      DataStore.menus.pop();
    }
    DataStore.persist(KEY_MENUS, DataStore.menus);
  }

  static getShopping(): ShoppingItem[] {
    return DataStore.shopping;
  }

  static setShopping(list: ShoppingItem[]): void {
    DataStore.shopping = list;
    DataStore.persist(KEY_SHOPPING, list);
    DataStore.publishShopping();
  }

  static clearCheckedShopping(): void {
    DataStore.shopping = DataStore.shopping.filter((s: ShoppingItem): boolean => !s.checked);
    DataStore.persist(KEY_SHOPPING, DataStore.shopping);
    DataStore.publishShopping();
  }

  static getStock(): StockItem[] {
    return DataStore.stock;
  }

  static setStock(list: StockItem[]): void {
    DataStore.stock = list;
    DataStore.persist(KEY_STOCK, list);
  }

  static addStock(items: StockItem[]): void {
    for (const it of items) {
      let merged: boolean = false;
      for (const ex of DataStore.stock) {
        if (ex.name === it.name) {
          ex.amount += it.amount;
          ex.buyDate = Math.max(ex.buyDate, it.buyDate);
          merged = true;
          break;
        }
      }
      if (!merged) {
        DataStore.stock.push(it);
      }
    }
    DataStore.persist(KEY_STOCK, DataStore.stock);
  }

  static removeStock(id: string): void {
    DataStore.stock = DataStore.stock.filter((s: StockItem): boolean => s.id !== id);
    DataStore.persist(KEY_STOCK, DataStore.stock);
  }

  /**
   * 按点菜情况扣减库存（FIFO：同名合并策略下单条目内扣减，先入库的先体现在剩余量上）。
   * 规则：
   * - 份数缩放：扣减量 = 菜谱用量 × (用餐人数 / 菜谱份数)，与采购清单口径一致；
   * - 未标注数量（amount<=0）的食材不扣减；
   * - 调料/调味菜（家里常备）不扣减，与采购清单过滤口径一致；
   * - 库存按「克」存的按数值扣；按份/个等计数的保守扣 1 份；
   * - 扣到 0 的条目自动移除（等同「用完了」）；
   * - 每处扣减写一条消耗日志（最近 200 条），食材页可见。
   * 返回实际扣减的库存条目数。
   */
  static consumeStock(menu: DailyMenu): number {
    let deducted: number = 0;
    const now: number = Date.now();
    const records: ConsumeRecord[] = [];
    for (const rid of menu.recipeIds) {
      const r: Recipe | null = DataStore.getRecipe(rid);
      if (r === null) {
        continue;
      }
      const ratio: number = menu.people / Math.max(1, r.servings);
      for (const ing of r.ingredients) {
        if (ing.amount <= 0) {
          continue;
        }
        const info = lookupFood(ing.name);
        if (info !== null && (info.category === '调料' || info.category === '调味菜')) {
          continue;
        }
        for (const st of DataStore.stock) {
          if (st.name === ing.name || (ing.name.indexOf(st.name) >= 0 && st.name.length >= 2)) {
            // 克类按缩放后数值扣；计数类保守扣 1 份
            const deduct: number = st.unit === '克'
              ? Math.min(st.amount, Math.round(ing.amount * ratio))
              : Math.min(st.amount, 1);
            if (deduct <= 0) {
              break;
            }
            st.amount = Math.max(0, st.amount - deduct);
            deducted += 1;
            records.push(new ConsumeRecord(
              `c${now}_${records.length}_${st.id}`, menu.id, menu.date, r.name,
              st.name, deduct, st.unit, now));
            break;
          }
        }
      }
    }
    // 扣到 0 的条目移除
    DataStore.stock = DataStore.stock.filter((s: StockItem): boolean => s.amount > 0);
    if (records.length > 0) {
      DataStore.consumeLog = records.concat(DataStore.consumeLog);
      if (DataStore.consumeLog.length > 200) {
        DataStore.consumeLog = DataStore.consumeLog.slice(0, 200);
      }
      DataStore.persist(KEY_CONSUME, DataStore.consumeLog);
    }
    DataStore.persist(KEY_STOCK, DataStore.stock);
    return deducted;
  }

  /** 消耗日志（最新在前） */
  static getConsumeLog(): ConsumeRecord[] {
    return DataStore.consumeLog;
  }

  /** 确认点菜记录：标记 confirmed 并持久化（防同一菜单重复扣减） */
  static confirmMenu(id: string): void {
    for (const m of DataStore.menus) {
      if (m.id === id) {
        m.confirmed = true;
        DataStore.persist(KEY_MENUS, DataStore.menus);
        return;
      }
    }
  }

  /** 校准库存数量（用户手动修正）；量到 0 视为用完移除 */
  static updateStockAmount(id: string, amount: number): void {
    for (const s of DataStore.stock) {
      if (s.id === id) {
        s.amount = Math.max(0, amount);
        s.calibratedRatio = 1;
        s.lastCalibrated = Date.now();
        break;
      }
    }
    DataStore.stock = DataStore.stock.filter((s: StockItem): boolean => s.amount > 0);
    DataStore.persist(KEY_STOCK, DataStore.stock);
  }
}
