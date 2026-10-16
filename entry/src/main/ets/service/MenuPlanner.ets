/**
 * 点菜规划：随机菜单 / 需求推荐（热量、预算、时令、库存优先）/ 采购清单生成。
 */
import { FoodInfo, lookupFood, seasonalVeggies } from './NutritionDB';
import { RecipeParser } from './RecipeParser';
import { DataStore } from './DataStore';
import { Freshness } from './Freshness';
import { DailyMenu, FreshLevel, Recipe, ShoppingItem, StockItem } from '../model/Models';

export class MenuPlanner {
  /** 搜索菜库 */
  static search(keyword: string): Recipe[] {
    return DataStore.searchRecipes(keyword);
  }

  /** 按人数随机生成菜单（1 汤/素 + N 荤，最多 人数+1 道） */
  static randomMenu(people: number): DailyMenu {
    const pool: Recipe[] = DataStore.getRecipes();
    const menu: DailyMenu = new DailyMenu();
    menu.id = `m${Date.now()}`;
    menu.date = MenuPlanner.today();
    menu.people = people;
    if (pool.length === 0) {
      return menu;
    }
    const dishCount: number = Math.max(2, Math.min(people + 1, pool.length));
    const shuffled: Recipe[] = MenuPlanner.shuffle(pool);
    // 临期优先：洗牌后把命中临期库存的菜谱前移（保持随机性，但急消耗的菜有更高入选率）
    const urgentNames: string[] = MenuPlanner.urgentStockNames();
    const ordered: Recipe[] = urgentNames.length > 0
      ? shuffled.slice().sort((a: Recipe, b: Recipe): number => {
        const ua: number = MenuPlanner.hitsUrgent(a, urgentNames) ? 0 : 1;
        const ub: number = MenuPlanner.hitsUrgent(b, urgentNames) ? 0 : 1;
        return ua - ub;
      })
      : shuffled;
    const picked: Recipe[] = ordered.slice(0, dishCount);
    menu.recipeIds = picked.map((r: Recipe): string => r.id);
    menu.recipeNames = picked.map((r: Recipe): string => r.name);
    MenuPlanner.fillTotals(menu, picked);
    return menu;
  }

  /** 菜谱是否命中任一临期食材 */
  private static hitsUrgent(r: Recipe, urgentNames: string[]): boolean {
    for (const ing of r.ingredients) {
      for (const un of urgentNames) {
        if (ing.name.indexOf(un) >= 0 || un.indexOf(ing.name) >= 0) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * 需求推荐。
   * maxKcal > 0：每人每餐热量上限；budget > 0：整桌预算上限（元）；
   * seasonal：优先时令蔬菜菜；useStock：优先消耗剩余食材。
   */
  static recommend(people: number, maxKcal: number, budget: number, seasonal: boolean, useStock: boolean): DailyMenu {
    let pool: Recipe[] = DataStore.getRecipes();
    const menu: DailyMenu = new DailyMenu();
    menu.id = `m${Date.now()}`;
    menu.date = MenuPlanner.today();
    menu.people = people;

    if (useStock) {
      const stockNames: string[] = DataStore.getStock().map((s): string => s.name);
      const urgentNames: string[] = MenuPlanner.urgentStockNames();
      const scored: Recipe[] = pool.slice().sort((a: Recipe, b: Recipe): number => {
        return MenuPlanner.stockScore(b, stockNames, urgentNames) - MenuPlanner.stockScore(a, stockNames, urgentNames);
      });
      pool = scored;
    }
    if (seasonal) {
      const seasonalSet: string[] = seasonalVeggies(new Date().getMonth() + 1);
      const matched: Recipe[] = pool.filter((r: Recipe): boolean =>
        r.ingredients.some((ing): boolean =>
          seasonalSet.some((sv: string): boolean => ing.name.indexOf(sv) >= 0)));
      if (matched.length >= 2) {
        pool = matched.concat(pool.filter((r: Recipe): boolean => matched.indexOf(r) < 0));
      }
    }
    if (maxKcal > 0) {
      const lowCal: Recipe[] = pool.filter((r: Recipe): boolean => r.nutrition.kcal <= maxKcal);
      if (lowCal.length >= 2) {
        pool = lowCal;
      }
    }

    const picked: Recipe[] = MenuPlanner.pickUnderBudget(pool, people, budget, maxKcal);
    menu.recipeIds = picked.map((r: Recipe): string => r.id);
    menu.recipeNames = picked.map((r: Recipe): string => r.name);
    MenuPlanner.fillTotals(menu, picked);
    return menu;
  }

  /** 临期库存品名（SOON/CHECK 级，月份代理口径；推荐加权用） */
  private static urgentStockNames(): string[] {
    const now: Date = new Date();
    return DataStore.getStock()
      .filter((s: StockItem): boolean =>
        Freshness.level(Freshness.decayRatioSync(s, now, Freshness.monthFactor(now))) >= FreshLevel.SOON)
      .map((s: StockItem): string => s.name);
  }

  /**
   * 库存匹配打分：普通库存命中 +2/食材；临期库存命中额外 +5（重加权，急消耗优先）。
   * 一个食材命中多库存只计一次。
   */
  private static stockScore(r: Recipe, stockNames: string[], urgentNames: string[]): number {
    let score: number = 0;
    for (const ing of r.ingredients) {
      let hit: boolean = false;
      for (const sn of stockNames) {
        if (ing.name.indexOf(sn) >= 0 || sn.indexOf(ing.name) >= 0) {
          score += 2;
          hit = true;
          break;
        }
      }
      if (!hit) {
        for (const un of urgentNames) {
          if (ing.name.indexOf(un) >= 0 || un.indexOf(ing.name) >= 0) {
            score += 5;
            break;
          }
        }
      } else {
        // 命中普通库存的食材若同时是临期库存（同名临期），也按临期加成
        for (const un of urgentNames) {
          if (un === ing.name) {
            score += 5;
            break;
          }
        }
      }
    }
    return score;
  }

  private static pickUnderBudget(pool: Recipe[], people: number, budget: number, maxKcal: number): Recipe[] {
    const picked: Recipe[] = [];
    let cost: number = 0;
    let kcalSum: number = 0;
    const dishCount: number = Math.max(2, Math.min(people + 1, pool.length));
    const shuffled: Recipe[] = MenuPlanner.shuffle(pool);
    for (const r of shuffled) {
      if (picked.length >= dishCount) {
        break;
      }
      const c: number = MenuPlanner.recipeCost(r);
      const kcal: number = r.nutrition.kcal;
      if (budget > 0 && cost + c > budget * 1.15) {
        continue;
      }
      if (maxKcal > 0 && picked.length > 0 && (kcalSum + kcal) / Math.max(1, picked.length + 1) > maxKcal * 1.2) {
        continue;
      }
      picked.push(r);
      cost += c;
      kcalSum += kcal;
    }
    if (picked.length === 0 && shuffled.length > 0) {
      picked.push(shuffled[0]);
    }
    return picked;
  }

  /** 一道菜的成本估算（按食材所需量 × 每斤价） */
  static recipeCost(r: Recipe): number {
    let cost: number = 0;
    for (const ing of r.ingredients) {
      const info: FoodInfo = lookupFood(ing.name) as FoodInfo;
      let grams: number = ing.amount;
      if (grams <= 0) {
        grams = (info.category === '肉类' || info.category === '主食' || info.category === '水产') ? 200 : 15;
      }
      cost += DataStore.pricePerKg(ing.name) * grams / 1000;
    }
    return Math.round(cost * 10) / 10;
  }

  private static fillTotals(menu: DailyMenu, picked: Recipe[], maxKcal: number = 0): void {
    let kcal: number = 0;
    let protein: number = 0;
    let fat: number = 0;
    let carbs: number = 0;
    let cost: number = 0;
    for (const r of picked) {
      kcal += r.nutrition.kcal;
      protein += r.nutrition.protein;
      fat += r.nutrition.fat;
      carbs += r.nutrition.carbs;
      cost += MenuPlanner.recipeCost(r);
    }
    const n: number = Math.max(1, picked.length);
    menu.totalKcal = picked.length === 0 ? 0 : Math.round(kcal / n);
    menu.protein = Math.round(protein / n * 10) / 10;
    menu.fat = Math.round(fat / n * 10) / 10;
    menu.carbs = Math.round(carbs / n * 10) / 10;
    menu.budget = Math.round(cost * 10) / 10;
    menu.review = MenuPlanner.menuReview(menu, picked, menu.people, maxKcal);
  }

  /**
   * 菜单结构审查：荤素汤配比与热量上限提示（推荐/随机完成后调用）。
   * 返回提示列表，空数组表示结构合理。
   */
  static menuReview(menu: DailyMenu, picked: Recipe[], people: number, maxKcal: number): string[] {
    const tips: string[] = [];
    const hasSoup: boolean = picked.some((r: Recipe): boolean => r.name.indexOf('汤') >= 0);
    if (people >= 3 && !hasSoup) {
      tips.push('3 人以上建议配一道汤');
    }
    let meat: number = 0;
    let veg: number = 0;
    for (const r of picked) {
      if (r.tags.indexOf('荤') >= 0) {
        meat += 1;
      } else if (r.tags.indexOf('素') >= 0) {
        veg += 1;
      }
    }
    if (meat > 0 && veg < meat - 1) {
      tips.push('荤素搭配偏重，可换一道素菜');
    }
    if (maxKcal > 0 && menu.totalKcal > maxKcal * 1.15) {
      const over: number = Math.round((menu.totalKcal / maxKcal - 1) * 100);
      tips.push(`热量超上限约 ${over}%，可去掉一道高热量菜`);
    }
    return tips;
  }

  /**
   * 生成采购清单：汇总菜单全部食材 × 人数/菜谱份数 倍率。
   * 价格给出 ±15% 区间；菜价参考（当日基础价）来自知识库每斤价。
   */
  static buildShoppingList(menu: DailyMenu): ShoppingItem[] {
    const map: Map<string, ShoppingItem> = new Map<string, ShoppingItem>();
    for (const rid of menu.recipeIds) {
      const r: Recipe | null = DataStore.getRecipe(rid);
      if (r === null) {
        continue;
      }
      const ratio: number = menu.people / Math.max(1, r.servings);
      for (const ing of r.ingredients) {
        const info: FoodInfo = lookupFood(ing.name) as FoodInfo;
        // 调料/调味菜不进采购清单（家里常备，且按斤估价无意义）
        if (info.category === '调料' || info.category === '调味菜') {
          continue;
        }
        let grams: number = ing.amount <= 0 ? ((info.category === '肉类' || info.category === '水产') ? 200 : 15) : ing.amount;
        grams = Math.round(grams * ratio);
        const key: string = ing.name;
        let item: ShoppingItem | undefined = map.get(key);
        if (item === undefined) {
          item = new ShoppingItem();
          item.name = ing.name;
          item.unit = ing.unit.length > 0 && ing.unit !== '适量' ? ing.unit : '克';
          item.category = info.category;
          item.amount = 0;
          map.set(key, item);
        }
        item.amount += grams;
      }
    }
    const list: ShoppingItem[] = Array.from(map.values());
    for (const it of list) {
      // 单价（元/千克）：本地小票真实价优先，回退知识库基准价（含云端同步覆盖）
      const perKg: number = DataStore.pricePerKg(it.name);
      // 单价与预计花费（按所需量 ±15%，保留 1 位小数）
      it.pricePerKg = Math.round(perKg * 10) / 10;
      const est: number = perKg * it.amount / 1000;
      it.priceLow = Math.max(0.5, Math.round(est * 0.85 * 10) / 10);
      it.priceHigh = Math.max(0.8, Math.round(est * 1.15 * 10) / 10);
      if (it.amount <= 0) {
        it.amount = 1;
        it.unit = '份';
        it.pricePerKg = 0;
        it.priceLow = 2;
        it.priceHigh = 5;
      }
    }
    // 排序：贵 → 便宜
    list.sort((a: ShoppingItem, b: ShoppingItem): number => b.priceHigh - a.priceHigh);
    return list;
  }

  static today(): string {
    const d: Date = new Date();
    const mm: string = `${d.getMonth() + 1}`.padStart(2, '0');
    const dd: string = `${d.getDate()}`.padStart(2, '0');
    return `${d.getFullYear()}-${mm}-${dd}`;
  }

  private static shuffle<T>(arr: T[]): T[] {
    const out: T[] = arr.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: T = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }
}
