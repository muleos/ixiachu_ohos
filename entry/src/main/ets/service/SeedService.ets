/**
 * 首启种子数据：预置「下厨房」精选菜谱（结构对齐 Sorosliu1029/recipe-crawler 与
 * ruter/xiachufang-api 的菜谱字段：name/cover/grade/category/materials/steps/tip）。
 * 仅在本地菜谱库为空且从未种入过时执行一次。
 */
import { util } from '@kit.ArkTS';
import { resourceManager } from '@kit.LocalizationKit';
import { Recipe, RecipeStep } from '../model/Models';
import { DataStore } from './DataStore';
import { RecipeParser } from './RecipeParser';

interface SeedMaterial {
  name: string;
  unit: string;
}

interface SeedStep {
  step: number;
  desc: string;
  img: string;
}

interface SeedRecipe {
  name: string;
  cover: string;
  grade: string;
  category: string;
  materials: SeedMaterial[];
  steps: SeedStep[];
  tip: string;
}

export class SeedService {
  private static readonly SEEDED_KEY: string = 'seeded_v1';

  static async seedIfNeed(context: Context): Promise<void> {
    if (DataStore.getSetting(SeedService.SEEDED_KEY) === '1') {
      return;
    }
    if (DataStore.getRecipes().length > 0) {
      DataStore.setSetting(SeedService.SEEDED_KEY, '1');
      return;
    }
    try {
      const raw: string = await SeedService.readRawFile(context, 'seed_recipes.json');
      const seeds: SeedRecipe[] = JSON.parse(raw) as SeedRecipe[];
      for (const s of seeds) {
        DataStore.saveRecipe(SeedService.toRecipe(s));
      }
      DataStore.setSetting(SeedService.SEEDED_KEY, '1');
    } catch (e) {
      // 种子失败不阻塞启动
    }
  }

  private static async readRawFile(context: Context, path: string): Promise<string> {
    const res: resourceManager.ResourceManager = context.resourceManager;
    const bytes: Uint8Array = await res.getRawFileContent(path);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  /** 种子条目 → Recipe：复用解析器的用量规整与营养估算 */
  static toRecipe(s: SeedRecipe): Recipe {
    const r: Recipe = new Recipe();
    r.id = `seed_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    r.name = s.name;
    r.category = s.category;
    r.grade = s.grade;
    r.tip = s.tip;
    r.source = '下厨房精选';
    r.importTime = Date.now();
    r.sourceText = s.name;
    for (const m of s.materials) {
      const ing = RecipeParser.ingredientFromRaw(`${m.name} ${m.unit}`);
      if (ing !== null) {
        r.ingredients.push(ing);
      }
    }
    for (const st of s.steps) {
      r.steps.push(new RecipeStep(st.step, st.desc));
    }
    r.nutrition = RecipeParser.estimateNutrition(r.ingredients, r.servings);
    r.tags = RecipeParser.deriveTags(r);
    return r;
  }
}
