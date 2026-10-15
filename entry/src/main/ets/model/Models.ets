/** I下厨 数据模型 */

/** 菜谱食材行 */
export class RecipeIngredient {
  name: string = '';
  /** 规格化数量（克/毫升，按需），0 表示未标注 */
  amount: number = 0;
  unit: string = '';
  /** 原文（如“五花肉 300g”） */
  raw: string = '';

  constructor(name: string, amount: number, unit: string, raw: string) {
    this.name = name;
    this.amount = amount;
    this.unit = unit;
    this.raw = raw;
  }
}

/** 菜谱做法步骤 */
export class RecipeStep {
  index: number = 0;
  text: string = '';

  constructor(index: number, text: string) {
    this.index = index;
    this.text = text;
  }
}

/** 营养估算（每份） */
export class NutritionEstimate {
  kcal: number = 0;
  protein: number = 0;
  fat: number = 0;
  carbs: number = 0;

  constructor(kcal: number, protein: number, fat: number, carbs: number) {
    this.kcal = kcal;
    this.protein = protein;
    this.fat = fat;
    this.carbs = carbs;
  }
}

/** 菜谱 */
export class Recipe {
  id: string = '';
  name: string = '';
  /** 默认份数 */
  servings: number = 2;
  ingredients: RecipeIngredient[] = [];
  steps: RecipeStep[] = [];
  nutrition: NutritionEstimate = new NutritionEstimate(0, 0, 0, 0);
  /** 标签：时令 / 家常 / 硬菜 等 */
  tags: string[] = [];
  /** 分类：家常菜 / 荤菜 / 素菜 / 汤羹 / 主食 / 在线（下厨房 API 结构对齐） */
  category: string = '';
  /** 评分（下厨房数据，如 "8.5"），空为未评分 */
  grade: string = '';
  /** 小贴士（下厨房数据） */
  tip: string = '';
  /** 来源：手动导入 / 下厨房精选 / 在线导入 */
  source: string = '手动导入';
  /** 原始导入文本 */
  sourceText: string = '';
  importTime: number = 0;
}

/** 一次点菜结果 */
export class DailyMenu {
  id: string = '';
  date: string = '';
  people: number = 2;
  recipeIds: string[] = [];
  recipeNames: string[] = [];
  /** 全桌总热量（每人） */
  totalKcal: number = 0;
  /** 预算估算（元） */
  budget: number = 0;
  /** 是否已确认开做：确认时按菜谱用量扣减库存，防重复扣减 */
  confirmed: boolean = false;
}

/** 采购清单条目 */
export class ShoppingItem {
  name: string = '';
  amount: number = 0;
  unit: string = '';
  category: string = '';
  /** 单价参考（元/千克，来源：超市及网络公开菜价） */
  pricePerKg: number = 0;
  /** 预计花费区间（元，按所需量 ±15%） */
  priceLow: number = 0;
  priceHigh: number = 0;
  checked: boolean = false;
}

/** 食材库存（采购入库） */
export class StockItem {
  id: string = '';
  name: string = '';
  amount: number = 0;
  unit: string = '';
  category: string = '';
  /** 采购日期（毫秒） */
  buyDate: number = 0;
  /** 该类食材基准可存天数（常温/冷藏综合） */
  baseShelfDays: number = 7;
  /** 校准：用户手动修正后的剩余比例 0~1，-1 表示未校准 */
  calibratedRatio: number = -1;
  /** 最近一次用户校准时间（毫秒），0 表示未校准过 */
  lastCalibrated: number = 0;
  /** 小票识别单价（元/千克，仅重量类条目），0 表示未知 */
  pricePerKg: number = 0;
  /** 小票识别单价（元/件，仅计数类条目），0 表示未知 */
  pricePerUnit: number = 0;
  /** 单价采集日期（yyyy-MM-dd，空表示无价格） */
  lastPriceDate: string = '';
}

/** 一次库存扣减记录（消耗日志） */
export class ConsumeRecord {
  id: string = '';
  /** 扣减发生的点菜记录 id */
  menuId: string = '';
  /** 点菜日期（yyyy-MM-dd） */
  date: string = '';
  /** 菜名 */
  recipeName: string = '';
  /** 食材名 */
  foodName: string = '';
  /** 扣减量 */
  amount: number = 0;
  /** 单位（克 或 库存原单位） */
  unit: string = '克';
  /** 时间戳（毫秒） */
  time: number = 0;

  constructor(menuId: string, date: string, recipeName: string, foodName: string, amount: number, unit: string, time: number) {
    this.menuId = menuId;
    this.date = date;
    this.recipeName = recipeName;
    this.foodName = foodName;
    this.amount = amount;
    this.unit = unit;
    this.time = time;
  }
}

/** 新鲜度状态 */
export enum FreshLevel {
  FRESH = 0,
  SOON = 1,
  CHECK = 2
}
