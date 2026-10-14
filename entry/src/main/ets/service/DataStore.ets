/** 本地数据仓库：preferences 持久化菜谱 / 点菜记录 / 采购清单 / 食材库存 */
import { preferences } from '@kit.ArkData';
import { DailyMenu, Recipe, ShoppingItem, StockItem } from '../model/Models';

const STORE_NAME: string = 'ixiachu_data';
const KEY_RECIPES: string = 'recipes_json';
const KEY_MENUS: string = 'menus_json';
const KEY_SHOPPING: string = 'shopping_json';
const KEY_STOCK: string = 'stock_json';

export class DataStore {
  private static store: preferences.Preferences | null = null;
  private static recipes: Recipe[] = [];
  private static menus: DailyMenu[] = [];
  private static shopping: ShoppingItem[] = [];
  private static stock: StockItem[] = [];
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
    // 版本号 +1：让订阅 dataRev 的页面在异步初始化完成后刷新一次
    DataStore.rev += 1;
    AppStorage.setOrCreate<number>('dataRev', DataStore.rev);
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
      return raw.length === 0 ? [] : JSON.parse(raw) as DailyMenu[];
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
      return raw.length === 0 ? [] : JSON.parse(raw) as StockItem[];
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
  }

  static clearCheckedShopping(): void {
    DataStore.shopping = DataStore.shopping.filter((s: ShoppingItem): boolean => !s.checked);
    DataStore.persist(KEY_SHOPPING, DataStore.shopping);
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

  /** 按点菜情况扣减库存（简单模型：每菜每食材用量按谱面量执行一次） */
  static consumeStock(recipeIds: string[]): void {
    for (const rid of recipeIds) {
      const r: Recipe | null = DataStore.getRecipe(rid);
      if (r === null) {
        continue;
      }
      for (const ing of r.ingredients) {
        for (const st of DataStore.stock) {
          if (st.name === ing.name || (ing.name.indexOf(st.name) >= 0 && st.name.length >= 2)) {
            st.amount = Math.max(0, st.amount - ing.amount);
            break;
          }
        }
      }
    }
    DataStore.persist(KEY_STOCK, DataStore.stock);
  }
}
