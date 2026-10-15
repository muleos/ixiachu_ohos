/**
 * 菜谱解析器：把文字版菜谱解析为 食材 / 做法 / 营养价值与热量估算。
 * 支持的常见格式：
 *   【食材】五花肉 300g、生抽 10ml、青椒 2个
 *   做法：
 *   1. 热锅下油...
 */
import { FoodInfo, lookupFood } from './NutritionDB';
import { NutritionEstimate, Recipe, RecipeIngredient, RecipeStep } from '../model/Models';
import { DataStore } from './DataStore';

const SEC_HEAD_ING: RegExp = /(食材|用料|材料|原料)[：:]?/;
const SEC_HEAD_STEP: RegExp = /(做法|步骤|烹饪方法|制作过程)[：:]?/;

/** 从一行里提取 “名称 + 数量单位” */
function parseIngredientLine(line: string): RecipeIngredient | null {
  const cleaned: string = line.replace(/[、，,;；]/g, ' ').trim();
  if (cleaned.length === 0) {
    return null;
  }
  // 匹配：名称 前置，数量单位在后（支持 300g / 300克 / 2个 / 半斤 / 适量 / 1勺）；{1,10} 允许盐/醋/糖等单字名
  const m: RegExpMatchArray | null = cleaned.match(
    /^([\u4e00-\u9fa5A-Za-z]{1,10})\s*(\d+(?:\.\d+)?)?\s*(克|g|G|千克|kg|公斤|斤|两|毫升|ml|ML|L|升|个|只|根|条|把|颗|瓣|片|块|勺|汤匙|茶匙|包|盒|袋|张|朵)?\s*(适量|少许)?$/);
  if (m === null) {
    // “五花肉300g”连写
    const m2: RegExpMatchArray | null = cleaned.match(
      /^([\u4e00-\u9fa5A-Za-z]{1,10})(\d+(?:\.\d+)?)(克|g|G|千克|kg|公斤|斤|两|毫升|ml|ML|个|只|根|条|把|颗|瓣|片|块|勺|汤匙|包|盒|袋|张|朵)$/);
    if (m2 === null) {
      return new RecipeIngredient(cleaned, 0, '适量', cleaned);
    }
    return normalize(m2[1], parseFloat(m2[2]), m2[3]);
  }
  const unitRaw: string = (m[3] ?? '') + (m[4] ?? '');
  const amt: number = m[2] === undefined ? 0 : parseFloat(m[2]);
  return normalize(m[1], amt, unitRaw.length > 0 ? unitRaw : (amt > 0 ? '个' : '适量'));
}

function normalize(name: string, amount: number, unit: string): RecipeIngredient {
  // 食材名归一：与小票识别共用别名表（番茄→西红柿），菜谱/库存/采购口径一致
  const std: string = DataStore.normalizeName(name);
  let grams: number = amount;
  const u: string = unit;
  if (u === '千克' || u === 'kg' || u === '公斤') {
    grams = amount * 1000;
  } else if (u === '斤') {
    grams = amount * 500;
  } else if (u === '两') {
    grams = amount * 50;
  } else if (u === '毫升' || u === 'ml' || u === 'ML' || u === 'L' || u === '升') {
    grams = (u === 'L' || u === '升') ? amount * 1000 : amount; // 液体密度≈1
  } else if (u === 'g' || u === 'G' || u === '克') {
    grams = amount;
  }
  return new RecipeIngredient(std, grams, u, `${name} ${amount}${u}`);
}

export class RecipeParser {
  /**
   * 解析文字菜谱。
   * 策略：优先按「食材/用料」「做法/步骤」分段；无段落标记时，
   * 数字编号开头的行为步骤，顿号/换行分隔的短行为食材。
   */
  static parse(text: string, nameFallback: string): Recipe {
    const recipe: Recipe = new Recipe();
    recipe.sourceText = text;
    recipe.importTime = Date.now();
    recipe.id = `r${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    // 菜名：第一行（去掉“菜谱：”等前缀）
    const lines: string[] = text.split(/\r?\n/).map((l: string): string => l.trim()).filter((l: string): boolean => l.length > 0);
    if (lines.length > 0) {
      const first: string = lines[0].replace(/^(菜谱|菜名|标题)[：:]/, '');
      recipe.name = first.length <= 20 ? first : nameFallback;
    }
    if (recipe.name.length === 0) {
      recipe.name = nameFallback;
    }
    recipe.servings = RecipeParser.detectServings(text);

    // 分段
    let section: number = 0; // 0 未知 1 食材 2 步骤
    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i];
      if (i === 0 && line === recipe.name) {
        continue;
      }
      if (SEC_HEAD_ING.test(line)) {
        section = 1;
        // 同行可能直接跟内容
        const inline: string = line.replace(SEC_HEAD_ING, '');
        RecipeParser.addIngredientText(recipe, inline);
        continue;
      }
      if (SEC_HEAD_STEP.test(line)) {
        section = 2;
        const inline: string = line.replace(SEC_HEAD_STEP, '');
        RecipeParser.addStepText(recipe, inline);
        continue;
      }
      if (section === 1) {
        RecipeParser.addIngredientText(recipe, line);
      } else if (section === 2) {
        RecipeParser.addStepText(recipe, line);
      } else {
        // 无标记：编号行当步骤，否则尝试当食材
        if (/^\d+[\.、）)]/.test(line)) {
          RecipeParser.addStepText(recipe, line);
        } else {
          RecipeParser.addIngredientText(recipe, line);
        }
      }
    }

    // 份数声明
    const mSrv: RegExpMatchArray | null = text.match(/(\d+)\s*人份?/);
    if (mSrv !== null) {
      const n: number = parseInt(mSrv[1], 10);
      if (n > 0 && n <= 20) {
        recipe.servings = n;
      }
    }

    recipe.nutrition = RecipeParser.estimateNutrition(recipe.ingredients, recipe.servings);
    recipe.tags = RecipeParser.deriveTags(recipe);
    return recipe;
  }

  private static detectServings(text: string): number {
    const m: RegExpMatchArray | null = text.match(/(\d+)\s*人份/);
    return m === null ? 2 : Math.max(1, Math.min(20, parseInt(m[1], 10)));
  }

  private static addIngredientText(recipe: Recipe, text: string): void {
    const t: string = text.trim();
    if (t.length === 0) {
      return;
    }
    const parts: string[] = t.split(/[、，,;；\n]/);
    for (const p of parts) {
      const ing: RecipeIngredient | null = parseIngredientLine(p.trim());
      if (ing !== null && ing.name.length >= 1 && ing.name.length <= 12) {
        // 去重：同名合并数量
        let found: boolean = false;
        for (const ex of recipe.ingredients) {
          if (ex.name === ing.name) {
            ex.amount += ing.amount;
            found = true;
            break;
          }
        }
        if (!found) {
          recipe.ingredients.push(ing);
        }
      }
    }
  }

  private static addStepText(recipe: Recipe, text: string): void {
    const t: string = text.trim();
    if (t.length < 2) {
      return;
    }
    const cleaned: string = t.replace(/^\d+[\.、）)]\s*/, '');
    recipe.steps.push(new RecipeStep(recipe.steps.length + 1, cleaned));
  }

  /** 热量与营养估算：食材克数 × 每100g营养 ÷ 份数；未标数量的按少量(15g)计 */
  static estimateNutrition(ings: RecipeIngredient[], servings: number): NutritionEstimate {
    let kcal: number = 0;
    let protein: number = 0;
    let fat: number = 0;
    let carbs: number = 0;
    for (const ing of ings) {
      const info: FoodInfo = lookupFood(ing.name) as FoodInfo;
      let grams: number = ing.amount;
      if (grams <= 0) {
        // 未标数量：主食类/肉类按常见量 200g，其余 15g
        grams = (info.category === '肉类' || info.category === '主食' || info.category === '水产') ? 200 : 15;
      }
      const ratio: number = grams / 100;
      kcal += info.kcal * ratio;
      protein += info.protein * ratio;
      fat += info.fat * ratio;
      carbs += info.carbs * ratio;
    }
    const div: number = Math.max(1, servings);
    return new NutritionEstimate(Math.round(kcal / div), Math.round(protein / div), Math.round(fat / div), Math.round(carbs / div));
  }

  /** 对外暴露：单行「名称+用量」解析（供种子数据/在线导入复用） */
  static ingredientFromRaw(raw: string): RecipeIngredient | null {
    const t: string = raw.trim();
    if (t.length === 0) {
      return null;
    }
    return parseIngredientLine(t);
  }

  static deriveTags(recipe: Recipe): string[] {
    const tags: string[] = [];
    let hasMeat: boolean = false;
    let hasVeg: boolean = false;
    for (const ing of recipe.ingredients) {
      const info: FoodInfo = lookupFood(ing.name) as FoodInfo;
      if (info.category === '肉类' || info.category === '水产') {
        hasMeat = true;
      }
      if (info.category === '叶菜' || info.category === '果菜' || info.category === '瓜菜') {
        hasVeg = true;
      }
    }
    if (hasMeat) {
      tags.push('荤');
    }
    if (hasVeg) {
      tags.push('素');
    }
    if (hasMeat && hasVeg) {
      tags.push('荤素搭配');
    }
    if (recipe.nutrition.kcal <= 250) {
      tags.push('低卡');
    } else if (recipe.nutrition.kcal >= 600) {
      tags.push('高热量');
    }
    if (recipe.steps.length <= 4) {
      tags.push('简单');
    }
    return tags;
  }
}
