/**
 * 下厨房在线导入 —— 接口结构对齐 ruter/xiachufang-api：
 *   GET {base}/recipe/{id}/        → { Content: [{ name, cover, grade, materials:[{name,unit}], steps:[{step,desc,img}], tip }] }
 *   GET {base}/search/{keyword}/   → { Page: {next}, Recipe: [{cover,name,url}] }
 * base 为自部署的 xiachufang-api 服务地址（可在导入页配置）。
 */
import { http } from '@kit.NetworkKit';
import { Recipe, RecipeStep } from '../model/Models';
import { RecipeParser } from './RecipeParser';

interface XfMaterial {
  name: string;
  unit: string;
}

interface XfStep {
  step: number;
  desc: string;
  img: string;
}

interface XfContent {
  name: string;
  cover: string;
  grade: string;
  materials: XfMaterial[];
  steps: XfStep[];
  tip: string;
}

interface XfDetailResponse {
  Content: XfContent[];
}

export class XiachufangApi {
  /** 从链接或纯数字中提取菜谱 ID：https://www.xiachufang.com/recipe/101772749/ → 101772749 */
  static extractId(input: string): string {
    const m: RegExpMatchArray | null = input.match(/recipe\/(\d+)/);
    if (m !== null) {
      return m[1];
    }
    const digits: RegExpMatchArray | null = input.trim().match(/^(\d+)$/);
    return digits === null ? '' : digits[1];
  }

  /** 拉取并解析一道菜谱；失败抛异常由页面提示 */
  static async fetchRecipe(base: string, id: string): Promise<Recipe> {
    const url: string = `${base.replace(/\/+$/, '')}/recipe/${id}/`;
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: { 'User-Agent': 'IXiaChu/1.1.0' }
      });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        throw new Error(`服务返回 ${resp.responseCode}`);
      }
      const data: XfDetailResponse = JSON.parse(resp.result as string) as XfDetailResponse;
      if (data.Content === undefined || data.Content.length === 0) {
        throw new Error('未找到该菜谱内容');
      }
      const c: XfContent = data.Content[0];
      const r: Recipe = new Recipe();
      r.id = `xf_${id}_${Date.now()}`;
      r.name = c.name;
      r.grade = c.grade ?? '';
      r.tip = c.tip ?? '';
      r.category = '在线导入';
      r.source = '在线导入';
      r.importTime = Date.now();
      r.sourceText = url;
      for (const m of c.materials) {
        const ing = RecipeParser.ingredientFromRaw(`${m.name} ${m.unit}`);
        if (ing !== null) {
          r.ingredients.push(ing);
        }
      }
      for (const st of c.steps) {
        r.steps.push(new RecipeStep(st.step, st.desc));
      }
      r.nutrition = RecipeParser.estimateNutrition(r.ingredients, r.servings);
      r.tags = RecipeParser.deriveTags(r);
      return r;
    } finally {
      req.destroy();
    }
  }
}
