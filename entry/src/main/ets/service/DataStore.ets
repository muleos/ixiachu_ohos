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

/** 内置别名表：[标准名, 别名...]（小票 OCR 品名 / 菜谱食材名归一到标准名） */
const BUILTIN_ALIASES: string[][] = [
  ['西红柿', '番茄', '洋柿子'],
  ['土豆', '马铃薯', '洋芋', '地蛋'],
  ['圆白菜', '包菜', '卷心菜', '椰菜'],
  ['花菜', '菜花', '花椰菜'],
  ['鸡蛋', '鸡卵'],
  ['青椒', '柿子椒', '甜椒', '菜椒'],
  ['大白菜', '白菜'],
  ['生菜', '叶用莴苣'],
  ['五花肉', '肋条肉', '五花猪肉'],
  ['猪肉', '瘦肉', '猪瘦肉'],
  ['排骨', '猪排骨', '肋排'],
  ['虾', '鲜虾', '大虾', '海虾', '基围虾'],
  ['豆腐', '水豆腐', '北豆腐', '南豆腐'],
  ['金针菇', '金菇'],
  ['洋葱', '圆葱', '葱头'],
  ['红薯', '地瓜', '番薯', '山芋'],
  ['莲藕', '藕', '鲜藕'],
  ['玉米', '苞米', '苞谷'],
  ['黄瓜', '青瓜', '刺瓜'],
  ['西兰花', '绿花菜', '青花菜'],
  ['山药', '薯蓣'],
  ['茄子', '紫茄'],
  ['鸡腿', '鸡全腿', '琵琶腿']
];

/** 用户改名沉淀的别名（学习）：alias → 标准名 */
const LEARNED_KEY: string = 'learned_alias_json';

/** 本地小票真实价（元/千克）：品名 → 采集记录（30 天内，中位数取价） */
const KEY_LOCAL_PRICES: string = 'local_prices_json';
const LOCAL_PRICE_TTL_DAYS: number = 30;
const LOCAL_PRICE_MAX_PER_NAME: number = 20;

/** 单条本地价采集记录 */
export class LocalPricePoint {
  /** 元/千克 */
  p: number = 0;
  /** 采集日期 yyyy-MM-dd */
  d: string = '';
}

export class DataStore {
  private static store: preferences.Preferences | null = null;
  private static recipes: Recipe[] = [];
  private static menus: DailyMenu[] = [];
  private static shopping: ShoppingItem[] = [];
  private static stock: StockItem[] = [];
  private static consumeLog: ConsumeRecord[] = [];
  /** 别名 → 标准名 映射（内置 + 用户学习沉淀合并） */
  private static aliasMap: Map<string, string> = new Map<string, string>();
  /** 本地小票真实价：品名 → 采集记录（最新在前） */
  private static localPrices: Map<string, LocalPricePoint[]> = new Map<string, LocalPricePoint[]>();
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
    DataStore.loadAliases();
    DataStore.loadLocalPrices();
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
      // 存量数据补默认字段（旧版无 lastCalibrated / 价格三字段）
      for (const s of list) {
        if (s.lastCalibrated === undefined || s.lastCalibrated === null) {
          s.lastCalibrated = 0;
        }
        if (s.pricePerKg === undefined || s.pricePerKg === null) {
          s.pricePerKg = 0;
        }
        if (s.pricePerUnit === undefined || s.pricePerUnit === null) {
          s.pricePerUnit = 0;
        }
        if (s.lastPriceDate === undefined || s.lastPriceDate === null) {
          s.lastPriceDate = '';
        }
        if (s.storage === undefined || s.storage === null || s.storage.length === 0) {
          s.storage = '冷藏';
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

  /** 构建别名映射：内置表 + 用户学习沉淀（持久化在 LEARNED_KEY） */
  private static loadAliases(): void {
    DataStore.aliasMap = new Map<string, string>();
    for (const group of BUILTIN_ALIASES) {
      const std: string = group[0];
      for (let i = 1; i < group.length; i++) {
        DataStore.aliasMap.set(group[i], std);
      }
    }
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(LEARNED_KEY, '') as string;
      if (raw.length > 0) {
        const learned: Map<string, string> = JSON.parse(raw) as Map<string, string>;
        learned.forEach((std: string, alias: string): void => {
          DataStore.aliasMap.set(alias, std);
        });
      }
    } catch (e) {
      // 学习表损坏时丢弃，仅用内置表
    }
  }

  /** 品名归一：别名表命中返回标准名，否则原样返回 */
  static normalizeName(name: string): string {
    const std: string | undefined = DataStore.aliasMap.get(name);
    return std === undefined ? name : std;
  }

  /**
   * 改名沉淀：用户在确认页把识别名 A 改成 B 时调用 learnAlias(B, A)——
   * 以后 OCR/解析再遇到 A 自动归一到 B。A===B 或 B 为空时忽略。
   */
  static learnAlias(std: string, alias: string): void {
    if (std.length === 0 || alias.length === 0 || std === alias) {
      return;
    }
    // 内置组内出现该别名时会被内置表覆盖，学习表优先级更高（后 set）
    DataStore.aliasMap.set(alias, std);
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(LEARNED_KEY, '') as string;
      const learned: Map<string, string> = raw.length > 0 ? JSON.parse(raw) as Map<string, string> : new Map<string, string>();
      learned.set(alias, std);
      DataStore.persist(LEARNED_KEY, learned);
    } catch (e) {
      // 持久化失败不影响本次会话内归一
    }
  }

  /** 载入本地小票价库并清理超期记录 */
  private static loadLocalPrices(): void {
    DataStore.localPrices = new Map<string, LocalPricePoint[]>();
    try {
      const raw: string = (DataStore.store as preferences.Preferences).getSync(KEY_LOCAL_PRICES, '') as string;
      if (raw.length === 0) {
        return;
      }
      const obj: Record<string, LocalPricePoint[]> = JSON.parse(raw) as Record<string, LocalPricePoint[]>;
      const cutoff: string = DataStore.dateBefore(LOCAL_PRICE_TTL_DAYS);
      for (const name of Object.keys(obj)) {
        const list: LocalPricePoint[] = (obj[name] ?? []).filter((p: LocalPricePoint): boolean =>
          p.p > 0 && p.d >= cutoff);
        if (list.length > 0) {
          DataStore.localPrices.set(name, list);
        }
      }
    } catch (e) {
      // 价库损坏时丢弃，回退知识库基准价
    }
  }

  /** n 天前的日期串（yyyy-MM-dd） */
  private static dateBefore(days: number): string {
    const d: Date = new Date(Date.now() - days * 86400000);
    const m: string = String(d.getMonth() + 1).padStart(2, '0');
    const day: string = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}`;
  }

  private static persistLocalPrices(): void {
    const obj: Record<string, LocalPricePoint[]> = {};
    DataStore.localPrices.forEach((list: LocalPricePoint[], name: string): void => {
      obj[name] = list;
    });
    DataStore.persist(KEY_LOCAL_PRICES, obj);
  }

  /**
   * 小票确认入库时采集真实菜价：仅重量类条目（元/kg），同名同价去重，
   * 每名留 20 条、超 30 天自动清理。
   */
  static addLocalPrices(items: StockItem[]): void {
    const today: string = DataStore.dateBefore(0);
    let changed: boolean = false;
    for (const it of items) {
      if (it.pricePerKg <= 0) {
        continue;
      }
      const list: LocalPricePoint[] = DataStore.localPrices.get(it.name) ?? [];
      // 同日同价去重（重复扫同一张小票不膨胀）
      if (list.some((p: LocalPricePoint): boolean => p.d === today && Math.abs(p.p - it.pricePerKg) < 0.01)) {
        continue;
      }
      const point: LocalPricePoint = new LocalPricePoint();
      point.p = it.pricePerKg;
      point.d = it.lastPriceDate.length > 0 ? it.lastPriceDate : today;
      list.unshift(point);
      if (list.length > LOCAL_PRICE_MAX_PER_NAME) {
        list.length = LOCAL_PRICE_MAX_PER_NAME;
      }
      DataStore.localPrices.set(it.name, list);
      changed = true;
    }
    if (changed) {
      DataStore.persistLocalPrices();
    }
  }

  /** 本地价条数（有真实价的品名数，供采购页展示来源） */
  static localPriceCount(): number {
    return DataStore.localPrices.size;
  }

  /**
   * 统一定价入口（元/千克）：本地小票真实价（30 天中位数）优先，
   * 无本地价回退知识库基准价（斤价 ×2，含云端同步覆盖）。
   */
  static pricePerKg(name: string): number {
    const list: LocalPricePoint[] | undefined = DataStore.localPrices.get(name);
    if (list !== undefined && list.length > 0) {
      const sorted: number[] = list.map((p: LocalPricePoint): number => p.p).sort((a: number, b: number): number => a - b);
      const mid: number = Math.floor(sorted.length / 2);
      const med: number = sorted.length % 2 === 1
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
      if (med > 0) {
        return Math.round(med * 100) / 100;
      }
    }
    const info = lookupFood(name);
    return info !== null ? info.pricePerJin * 2 : 0;
  }

  /** 清空本地小票价库（设置页数据维护） */
  static clearLocalPrices(): void {
    DataStore.localPrices = new Map<string, LocalPricePoint[]>();
    const empty: Record<string, LocalPricePoint[]> = {};
    DataStore.persist(KEY_LOCAL_PRICES, empty);
  }

  /** 某品名是否有本地真实价（采购页标记用） */
  static hasLocalPrice(name: string): boolean {
    const list: LocalPricePoint[] | undefined = DataStore.localPrices.get(name);
    return list !== undefined && list.length > 0;
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
          // 价格以最新一次采购为准
          if (it.pricePerKg > 0) {
            ex.pricePerKg = it.pricePerKg;
          }
          if (it.pricePerUnit > 0) {
            ex.pricePerUnit = it.pricePerUnit;
          }
          if (it.lastPriceDate.length > 0) {
            ex.lastPriceDate = it.lastPriceDate;
          }
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
            const rec: ConsumeRecord = new ConsumeRecord(menu.id, menu.date, r.name, st.name, deduct, st.unit, now);
            rec.id = `c${now}_${records.length}_${st.id}`;
            records.push(rec);
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

  /** 校准库存数量与储存状态（用户手动修正）；量到 0 视为用完移除 */
  static updateStockAmount(id: string, amount: number, storage: string): void {
    for (const s of DataStore.stock) {
      if (s.id === id) {
        s.amount = Math.max(0, amount);
        s.calibratedRatio = 1;
        s.lastCalibrated = Date.now();
        if (storage === '常温' || storage === '冷藏' || storage === '冷冻') {
          s.storage = storage;
        }
        break;
      }
    }
    DataStore.stock = DataStore.stock.filter((s: StockItem): boolean => s.amount > 0);
    DataStore.persist(KEY_STOCK, DataStore.stock);
  }
}
