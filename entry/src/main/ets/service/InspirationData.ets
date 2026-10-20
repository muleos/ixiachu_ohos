/**
 * 灵感页数据源（v1.11.0）：二十四节气/季节内容、风味秘籍、季节菜谱匹配。
 * 纯本地静态内容 + 与用户菜单库联动（按关键词匹配当季菜谱）。
 */
import { Recipe } from '../model/Models';
import { DataStore } from './DataStore';

export class SeasonInfo {
  key: string = '';
  sub: string = '';
  term: string = '';
  title: string = '';
  desc: string = '';
  chips: string[] = [];
  keywords: string[] = [];

  /** 菜单库中匹配当季关键词的菜谱数（最少按 3 道展示口径） */
  matchCount(): number {
    return Math.max(3, InspirationData.matchSeason(this.key).length);
  }
}

/** 节气近似日期表（每月一个代表节气，按已过计算当前节气；误差 ±7 天可接受） */
const TERMS: string[] = [
  '小寒', '立春', '惊蛰', '清明', '立夏', '芒种', '小暑', '立秋', '白露', '寒露', '立冬', '大雪'
];
const TERM_DAYS: number[] = [5, 4, 6, 5, 6, 6, 7, 7, 7, 8, 7, 7];

export class InspirationData {
  static readonly tips: string[] = [
    '热汤面或云吞出锅前点入数滴焙焙纯芝麻油，撒一把切碎小葱白，香气扑鼻直沁心脾。',
    '炒鸡蛋时加几滴料酒与一小撮温水，蛋花更蓬松滑嫩；全程大火快翻，凝固即出锅。',
    '炖肉焯水后用温水冲洗，肉质不紧缩；炖煮中途别加冷水，蛋白质遇冷收缩口感变柴。',
    '凉拌菜最后再放盐和醋，早放会杀出水分冲淡调味；临上桌淋几滴香油锁住风味。',
    '煎鱼前用姜片擦一遍热锅再下油，鱼皮不易破；下锅后别急着翻面，定型后再翻。',
    '煮米饭加一小勺油和几滴柠檬汁，米粒晶莹松散、隔夜也不发硬。',
    '焯绿叶菜时水里加点盐和油，菜色更翠绿；焯完过一遍凉水，口感爽脆不坨。'
  ];

  /** 四季内容 */
  private static seasons: Map<string, SeasonInfo> = new Map<string, SeasonInfo>();

  static seasonOf(now: Date): SeasonInfo {
    const m: number = now.getMonth() + 1;
    let key: string = '秋';
    if (m >= 3 && m <= 5) {
      key = '春';
    } else if (m >= 6 && m <= 8) {
      key = '夏';
    } else if (m >= 9 && m <= 11) {
      key = '秋';
    }
    return InspirationData.seasonByKey(key);
  }

  /** 按季节 key 取内容（term 随当天日期计算） */
  static seasonByKey(key: string): SeasonInfo {
    const info: SeasonInfo | undefined = InspirationData.buildSeasons().get(key);
    const out: SeasonInfo = info !== undefined ? info : InspirationData.buildSeasons().get('秋') as SeasonInfo;
    out.term = InspirationData.currentTerm(new Date());
    return out;
  }

  /** 当前节气（近似）：取日期表中最近一个已过的节气 */
  static currentTerm(now: Date): string {
    const m: number = now.getMonth() + 1; // 1~12
    const d: number = now.getDate();
    // TERMS[i] 对应第 i+1 月的 TERM_DAYS[i]
    let term: string = TERMS[11]; // 默认大雪（跨年到1月小寒前）
    if (m === 1 && d < TERM_DAYS[0]) {
      return '冬至';
    }
    for (let i = 0; i < 12; i++) {
      if (m === i + 1) {
        term = d >= TERM_DAYS[i] ? TERMS[i] : (i === 0 ? '冬至' : TERMS[i - 1]);
        break;
      }
    }
    return term;
  }

  /** 按季节关键词匹配菜单库菜谱；不足 3 道用随机菜谱补齐 */
  static matchSeason(key: string): Recipe[] {
    const info: SeasonInfo | undefined = InspirationData.buildSeasons().get(key);
    if (info === undefined) {
      return [];
    }
    const all: Recipe[] = DataStore.getRecipes();
    const hits: Recipe[] = [];
    const rest: Recipe[] = [];
    for (const r of all) {
      const hay: string = `${r.name}|${r.tags.join(',')}|${r.category}|${r.ingredients.map((i): string => i.name).join(',')}`;
      let matched: boolean = false;
      for (const kw of info.keywords) {
        if (hay.indexOf(kw) >= 0) {
          matched = true;
          break;
        }
      }
      if (matched) {
        hits.push(r);
      } else {
        rest.push(r);
      }
    }
    // 补齐到至少 3 道（随机取，避免每次一样）
    while (hits.length < 3 && rest.length > 0) {
      const i: number = Math.floor(Math.random() * rest.length);
      hits.push(rest.splice(i, 1)[0]);
    }
    return hits;
  }

  private static buildSeasons(): Map<string, SeasonInfo> {
    if (InspirationData.seasons.size > 0) {
      return InspirationData.seasons;
    }
    const spring: SeasonInfo = new SeasonInfo();
    spring.key = '春';
    spring.sub = '春鲜';
    spring.title = '万物生发，尝一口春鲜';
    spring.desc = '鲜嫩春菜集中上市，清炒与焯水凉拌最能保留春日鲜味。';
    spring.chips = ['春笋', '芦笋', '荠菜', '韭菜', '豌豆', '菠菜'];
    spring.keywords = ['笋', '芦笋', '荠菜', '韭菜', '豌豆', '菠菜', '香椿', '蚕豆'];

    const summer: SeasonInfo = new SeasonInfo();
    summer.key = '夏';
    summer.sub = '夏清';
    summer.title = '消暑开胃，清爽一夏';
    summer.desc = '暑热当头，清热解腻的瓜果与凉菜最抚胃口。';
    summer.chips = ['苦瓜', '冬瓜', '丝瓜', '黄瓜', '番茄', '绿豆'];
    summer.keywords = ['苦瓜', '冬瓜', '丝瓜', '黄瓜', '番茄', '绿豆', '凉拌', '西瓜'];

    const autumn: SeasonInfo = new SeasonInfo();
    autumn.key = '秋';
    autumn.sub = '秋润';
    autumn.title = '温润丰收，慢品秋日清甜';
    autumn.desc = '根茎、坚果与白色食材丰盈上市，炖煮和焖烧最能释放绵甜香气。';
    autumn.chips = ['莲藕', '板栗', '百合', '梨', '南瓜', '山药'];
    autumn.keywords = ['莲藕', '藕', '板栗', '百合', '梨', '南瓜', '山药', '银耳'];

    const winter: SeasonInfo = new SeasonInfo();
    winter.key = '冬';
    winter.sub = '冬藏';
    winter.title = '围炉进补，暖意冬藏';
    winter.desc = '温补炖锅正当时，慢火煨出一锅全身暖意。';
    winter.chips = ['白萝卜', '白菜', '红薯', '羊肉', '冬笋', '豆腐'];
    winter.keywords = ['萝卜', '白菜', '红薯', '羊肉', '冬笋', '豆腐', '炖', '火锅'];

    InspirationData.seasons.set('春', spring);
    InspirationData.seasons.set('夏', summer);
    InspirationData.seasons.set('秋', autumn);
    InspirationData.seasons.set('冬', winter);
    return InspirationData.seasons;
  }
}
