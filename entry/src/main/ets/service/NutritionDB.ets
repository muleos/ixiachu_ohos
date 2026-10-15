/** 食材营养 / 价格 / 储存知识库（简化本地知识库，可扩展） */

export class FoodInfo {
  /** 每100g 热量 kcal */
  kcal: number = 0;
  protein: number = 0;
  fat: number = 0;
  carbs: number = 0;
  /** 每斤参考价（元） */
  pricePerJin: number = 0;
  /** 基准可存天数 */
  shelfDays: number = 7;
  category: string = '其他';

  constructor(kcal: number, protein: number, fat: number, carbs: number,
    pricePerJin: number, shelfDays: number, category: string) {
    this.kcal = kcal;
    this.protein = protein;
    this.fat = fat;
    this.carbs = carbs;
    this.pricePerJin = pricePerJin;
    this.shelfDays = shelfDays;
    this.category = category;
  }
}

const DB: Map<string, FoodInfo> = new Map<string, FoodInfo>();

function put(name: string, info: FoodInfo): void {
  DB.set(name, info);
}

function putMany(names: string[], info: FoodInfo): void {
  for (const n of names) {
    DB.set(n, info);
  }
}

// 肉禽蛋
putMany(['五花肉', '猪肉', '瘦肉', '排骨', '肉末', '肉馅'], new FoodInfo(395, 13, 37, 2,18, 3, '肉类'));
putMany(['牛肉', '牛腩', '牛里脊'], new FoodInfo(250, 20, 15, 2,38, 3, '肉类'));
putMany(['鸡肉', '鸡腿', '鸡翅', '鸡胸肉'], new FoodInfo(167, 19, 9, 1,12, 3, '肉类'));
putMany(['羊肉'], new FoodInfo(294, 18, 24, 0,32, 3, '肉类'));
putMany(['培根', '午餐肉', '火腿', '香肠'], new FoodInfo(500, 15, 45, 8,20, 14, '肉类'));
putMany(['鸡蛋', '蛋'], new FoodInfo(144, 13, 9, 2,5.5, 20, '蛋类'));
putMany(['虾', '基围虾', '虾仁'], new FoodInfo(93, 18, 1, 1,30, 2, '水产'));
putMany(['鱼', '鲈鱼', '鲫鱼', '带鱼'], new FoodInfo(120, 18, 5, 0,15, 2, '水产'));
putMany(['豆腐', '豆干', '豆皮', '腐竹'], new FoodInfo(120, 10, 6, 6,5, 3, '豆制品'));

// 蔬菜
putMany(['白菜', '大白菜', '小白菜', '青菜', '油菜', '生菜', '菠菜', '苋菜', '空心菜', '芹菜', '韭菜', '茼蒿'], new FoodInfo(25, 2, 0.3, 4,3, 3, '叶菜'));
putMany(['番茄', '西红柿'], new FoodInfo(20, 1, 0.2, 4,5, 7, '果菜'));
putMany(['黄瓜'], new FoodInfo(16, 0.8, 0.2, 3,4, 7, '果菜'));
putMany(['茄子'], new FoodInfo(23, 1, 0.2, 5,4.5, 7, '果菜'));
putMany(['辣椒', '青椒', '尖椒', '彩椒'], new FoodInfo(22, 1, 0.2, 5,6, 7, '果菜'));
putMany(['土豆', '马铃薯', '红薯', '山药', '芋头', '莲藕'], new FoodInfo(88, 2, 0.2, 20,2.8, 20, '根茎'));
putMany(['萝卜', '白萝卜', '胡萝卜'], new FoodInfo(35, 1, 0.2, 8,2, 20, '根茎'));
putMany(['洋葱', '大蒜', '蒜', '姜', '葱', '小葱', '大葱', '香菜'], new FoodInfo(40, 1.5, 0.2, 9,5, 15, '调味菜'));
putMany(['冬瓜', '南瓜', '丝瓜', '西葫芦', '苦瓜', '葫芦'], new FoodInfo(20, 0.8, 0.2, 4,3, 10, '瓜菜'));
putMany(['蘑菇', '香菇', '金针菇', '杏鲍菇', '平菇', '木耳'], new FoodInfo(30, 3, 0.3, 5,9, 5, '菌菇'));
putMany(['西兰花', '花菜', '菜花'], new FoodInfo(34, 2.8, 0.4, 6,6.5, 7, '花菜'));

// v1.2.2 新增（菜谱库扩充食材）
putMany(['鸭肉', '鸭腿'], new FoodInfo(240, 16, 19, 0, 14, 3, '肉类'));
putMany(['花生'], new FoodInfo(570, 25, 44, 16, 8, 180, '其他'));
putMany(['豆角', '四季豆', '豇豆'], new FoodInfo(31, 2.5, 0.2, 6, 6, 5, '果菜'));
putMany(['包菜', '卷心菜', '圆白菜'], new FoodInfo(24, 1.5, 0.2, 5, 2.5, 10, '叶菜'));
putMany(['蒜苔', '蒜薹'], new FoodInfo(61, 2, 0.1, 15, 8, 5, '果菜'));
putMany(['玉米'], new FoodInfo(106, 4, 1.2, 23, 4, 7, '根茎'));
putMany(['豆芽', '绿豆芽', '黄豆芽'], new FoodInfo(18, 2, 0.1, 3, 2.5, 2, '其他'));
putMany(['小米'], new FoodInfo(358, 9, 3, 73, 6, 180, '主食'));
putMany(['银耳'], new FoodInfo(200, 10, 1.4, 48, 30, 365, '其他'));
putMany(['莲子'], new FoodInfo(350, 17, 2, 67, 22, 365, '其他'));
putMany(['红枣'], new FoodInfo(280, 4, 0.5, 70, 12, 365, '其他'));
putMany(['枸杞'], new FoodInfo(250, 13, 1, 55, 35, 365, '其他'));
putMany(['啤酒'], new FoodInfo(43, 0.5, 0, 3.5, 5, 180, '其他'));
putMany(['番茄酱'], new FoodInfo(80, 1.5, 0.5, 18, 8, 365, '调料'));
putMany(['冰糖'], new FoodInfo(400, 0, 0, 99, 6, 365, '调料'));
putMany(['香油'], new FoodInfo(898, 0, 99.8, 0, 25, 365, '调料'));
putMany(['蒸鱼豉油'], new FoodInfo(60, 3, 0, 10, 10, 365, '调料'));
putMany(['蚝油'], new FoodInfo(90, 2, 0.3, 20, 10, 365, '调料'));

// 主食 / 其他
putMany(['米饭', '米', '大米'], new FoodInfo(116, 2.6, 0.3, 25,3, 180, '主食'));
putMany(['面条', '面', '挂面'], new FoodInfo(110, 3.5, 0.4, 22,4, 180, '主食'));
putMany(['面粉', '饺子皮', '馄饨皮'], new FoodInfo(350, 10, 1, 73,3, 180, '主食'));
putMany(['油'], new FoodInfo(900, 0, 100, 0,11, 365, '调料'));
putMany(['盐', '糖', '酱油', '醋', '料酒', '生抽', '老抽', '蚝油', '豆瓣酱', '淀粉', '鸡精', '胡椒', '五香粉', '花椒', '八角'], new FoodInfo(20, 0.5, 0.2, 4,9, 365, '调料'));

export function lookupFood(name: string): FoodInfo | null {
  const direct: FoodInfo | undefined = DB.get(name);
  if (direct !== undefined) {
    return direct;
  }
  // 关键词包含匹配（如“五花肉片”命中“五花肉”）
  const keys: string[] = Array.from(DB.keys());
  for (const k of keys) {
    if (name.indexOf(k) >= 0 && k.length >= 2) {
      return DB.get(k) ?? null;
    }
  }
  // 未知食材保守估算
  return new FoodInfo(60, 2, 1, 10, 6, 7, '其他');
}

/** 时令蔬菜（按月份 1~12） */
export function seasonalVeggies(month: number): string[] {
  if (month <= 2 || month === 12) {
    return ['白菜', '萝卜', '土豆', '菠菜', '山药', '莲藕'];
  }
  if (month <= 5) {
    return ['韭菜', '菠菜', '生菜', '豌豆', '芹菜', '春笋'];
  }
  if (month <= 8) {
    return ['黄瓜', '番茄', '茄子', '丝瓜', '苦瓜', '空心菜', '辣椒'];
  }
  return ['南瓜', '冬瓜', '莲藕', '山药', '白菜', '萝卜'];
}

/** 云端菜价文件结构：{ updated: "2026-10-15", source: "惠友到家", prices: { "五花肉": 17.8, ... } }（元/斤） */
interface PriceFile {
  updated: string;
  source: string;
  prices: Record<string, number>;
}

/**
 * 应用云端菜价覆盖：直接改写知识库内 FoodInfo 的基准价，
 * 所有 lookupFood 调用方（点菜预算 / 采购估价）自动生效。
 * 返回成功匹配并覆盖的条数。
 */
export function applyPriceOverrides(json: string): number {
  let applied: number = 0;
  try {
    const file: PriceFile = JSON.parse(json) as PriceFile;
    if (file.prices === undefined || file.prices === null) {
      return 0;
    }
    const keys: string[] = Array.from(DB.keys());
    const names: string[] = Object.keys(file.prices);
    for (const name of names) {
      const ppj: number = file.prices[name];
      if (ppj <= 0 || ppj > 999) {
        continue;
      }
      // 精确命中 → 直接覆盖；否则按包含关系匹配别名（「西红柿」↔「番茄」等共用实例）
      const direct: FoodInfo | undefined = DB.get(name);
      if (direct !== undefined) {
        direct.pricePerJin = ppj;
        applied++;
        continue;
      }
      let matched: boolean = false;
      for (const k of keys) {
        if (k.length >= 2 && (name.indexOf(k) >= 0 || k.indexOf(name) >= 0)) {
          const info: FoodInfo | undefined = DB.get(k);
          if (info !== undefined) {
            info.pricePerJin = ppj;
            applied++;
            matched = true;
          }
          break;
        }
      }
      if (matched) {
        continue;
      }
    }
  } catch (e) {
    return applied;
  }
  return applied;
}
