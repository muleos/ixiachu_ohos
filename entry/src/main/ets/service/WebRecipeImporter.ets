/**
 * 网页菜谱导入（v1.11.0，替代下厨房专用 API）：
 * 抓取任意网页（下厨房/小红书/微博等帖子页）→ 提取标题/描述/正文文本 + 图片列表
 * → 文本交 RecipeParser 生成菜谱；图片下载到本机随菜谱保存。
 * 无头浏览环境拿不到的内容（部分站点 JS 渲染/需登录）会提取失败，
 * 此时把原始文本回填到导入框由用户手动修正。
 */
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'WebRecipe';
const DOMAIN: number = 0x1CA;

export class WebPageContent {
  ok: boolean = false;
  message: string = '';
  title: string = '';
  desc: string = '';
  /** 正文净化文本（去脚本/样式/标签后的可读行） */
  text: string = '';
  /** 图片直链（og:image 优先，其后正文 img，最多 6 条） */
  imageUrls: string[] = [];
}

export class WebRecipeImporter {
  private static readonly UA: string =
    'Mozilla/5.0 (Linux; HarmonyOS NEXT) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36 IXiaChu/1.11.0';

  /** 规范化链接：补 https、去尾部分享追踪参数（保留 path） */
  static normalizeUrl(input: string): string {
    let u: string = input.trim();
    if (u.length === 0) {
      return '';
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = `https://${u}`;
    }
    return u;
  }

  /** 抓取网页并提取结构化内容 */
  static async fetchPage(url: string): Promise<WebPageContent> {
    const out: WebPageContent = new WebPageContent();
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 15000,
        header: {
          'User-Agent': WebRecipeImporter.UA,
          'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8'
        },
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        out.message = `网页返回 ${resp.responseCode}，该站点可能需要登录或仅 App 内可见`;
        return out;
      }
      const html: string = typeof resp.result === 'string' ? resp.result : '';
      if (html.length < 50) {
        out.message = '网页内容为空或为脚本渲染，无法提取';
        return out;
      }
      out.title = WebRecipeImporter.metaOf(html, ['og:title', 'twitter:title']);
      if (out.title.length === 0) {
        const tm: RegExpMatchArray | null = html.match(/<title[^>]*>([^<]{1,120})<\/title>/i);
        if (tm !== null) {
          out.title = WebRecipeImporter.decodeEntities(tm[1]).trim();
        }
      }
      out.desc = WebRecipeImporter.metaOf(html, ['og:description', 'description', 'twitter:description']);
      out.imageUrls = WebRecipeImporter.extractImages(html);
      out.text = WebRecipeImporter.extractText(html);
      out.ok = out.title.length > 0 || out.text.length > 20;
      if (!out.ok) {
        out.message = '未能从该网页提取到有效内容（站点多为脚本渲染），可截图后用「图片识别」导入';
      }
      hilog.info(DOMAIN, TAG, 'fetch ok title=%{public}s textLen=%{public}d imgs=%{public}d',
        out.title, out.text.length, out.imageUrls.length);
      return out;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'fetch failed: %{public}s', (e as Error).message);
      out.message = '网页抓取失败，请检查链接与网络';
      return out;
    } finally {
      req.destroy();
    }
  }

  /** og/twitter/meta 提取（content 属性，兼容单双引号与属性顺序） */
  private static metaOf(html: string, keys: string[]): string {
    for (const k of keys) {
      const re: RegExp =
        new RegExp(`<meta[^>]+(?:property|name)=["']${k}["'][^>]*>`, 'i');
      const tag: RegExpMatchArray | null = html.match(re);
      if (tag === null) {
        continue;
      }
      const cm: RegExpMatchArray | null = tag[0].match(/content=["']([^"']{1,600})["']/i);
      if (cm !== null && cm[1].trim().length > 0) {
        return WebRecipeImporter.decodeEntities(cm[1]).trim();
      }
    }
    return '';
  }

  /** 图片直链：og:image 优先，正文 img 兜底（过滤头像/图标//base64），最多 6 条 */
  private static extractImages(html: string): string[] {
    const urls: string[] = [];
    const push = (u: string): void => {
      const t: string = WebRecipeImporter.decodeEntities(u).trim();
      if (t.length === 0 || !t.startsWith('http')) {
        return;
      }
      if (t.indexOf('avatar') >= 0 || t.indexOf('icon') >= 0 || t.indexOf('logo') >= 0) {
        return;
      }
      if (urls.indexOf(t) < 0 && urls.length < 6) {
        urls.push(t);
      }
    };
    const og: RegExpMatchArray | null =
      html.match(/<meta[^>]+property=["']og:image["'][^>]*>/i);
    if (og !== null) {
      const cm: RegExpMatchArray | null = og[0].match(/content=["']([^"']+)["']/i);
      if (cm !== null) {
        push(cm[1]);
      }
    }
    const imgRe: RegExp = /<img[^>]+src=["'](https?:\/\/[^"']+)["']/gi;
    let m: RegExpExecArray | null = imgRe.exec(html);
    while (m !== null && urls.length < 6) {
      push(m[1]);
      m = imgRe.exec(html);
    }
    return urls;
  }

  /** 正文净化：去 script/style → 块级标签转行 → 剥标签 → 解实体 → 去噪行 */
  private static extractText(html: string): string {
    let s: string = html
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<\/(p|div|li|h[1-6]|tr|section)>/gi, '\n')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, ' ');
    s = WebRecipeImporter.decodeEntities(s);
    const lines: string[] = [];
    for (let raw of s.split(/\n/)) {
      const line: string = raw.replace(/[ \t\u3000]+/g, ' ').trim();
      if (line.length < 2) {
        continue;
      }
      // 站点导航/推荐噪音：纯短链接词、关注/下载引导等
      if (/^(首页|登录|注册|下载|客户端|关注|复制链接|打开|查看更多|相关推荐|热门|评论|点赞|分享|收藏)$/.test(line)) {
        continue;
      }
      if (lines.length === 0 || lines[lines.length - 1] !== line) {
        lines.push(line);
      }
    }
    return lines.join('\n');
  }

  /** 常见 HTML 实体解码（不引入 DOM） */
  private static decodeEntities(s: string): string {
    return s
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'")
      .replace(/&#x([0-9a-fA-F]+);/g, (m: string, p: string): string =>
        String.fromCharCode(parseInt(p, 16)))
      .replace(/&#(\d+);/g, (m: string, p: string): string =>
        String.fromCharCode(parseInt(p, 10)));
  }

  /**
   * 下载图片到应用 files/images 目录，返回本地路径；失败返回空串。
   * 扩展名按 URL 猜测（默认 .jpg；webp/png 保留原扩展，Image 组件均可解码）。
   */
  static async downloadImage(ctx: common.UIAbilityContext, url: string): Promise<string> {
    const req: http.HttpRequest = http.createHttp();
    try {
      // 小红书 CDN 不带 Referer 会 403，补上来源提升配图下载成功率
      const isXhs: boolean = url.indexOf('xhscdn.com') >= 0 || url.indexOf('xiaohongshu.com') >= 0;
      const header: Record<string, string> = { 'User-Agent': WebRecipeImporter.UA };
      if (isXhs) {
        header['Referer'] = 'https://www.xiaohongshu.com/';
      }
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 15000,
        header: header,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (resp.responseCode !== 200) {
        return '';
      }
      const buf: ArrayBuffer = resp.result as ArrayBuffer;
      if (buf.byteLength < 1024) {
        return '';
      }
      const dir: string = `${ctx.filesDir}/images`;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
      let ext: string = '.jpg';
      const em: RegExpMatchArray | null = url.match(/\.(jpe?g|png|webp)(?:[?#].*)?$/i);
      if (em !== null) {
        ext = `.${em[1].toLowerCase().replace('jpeg', 'jpg')}`;
      }
      const dest: string = `${dir}/web_${Date.now()}_${Math.floor(Math.random() * 900 + 100)}${ext}`;
      const f: fileIo.File = fileIo.openSync(dest, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      try {
        fileIo.writeSync(f.fd, buf);
      } finally {
        try {
          fileIo.closeSync(f);
        } catch (e) {
        }
      }
      hilog.info(DOMAIN, TAG, 'image saved %{public}s (%{public}d B)', dest, buf.byteLength);
      return dest;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'image download failed: %{public}s', (e as Error).message);
      return '';
    } finally {
      req.destroy();
    }
  }

  /** 抓取小红书笔记页并按 INITIAL_STATE 通道解析 */
  static async fetchXhs(url: string): Promise<WebPageContent> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 15000,
        header: { 'User-Agent': WebRecipeImporter.UA },
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        const fail: WebPageContent = new WebPageContent();
        fail.message = `小红书返回 ${resp.responseCode}，可稍后重试`;
        return fail;
      }
      const html: string = typeof resp.result === 'string' ? resp.result : '';
      return WebRecipeImporter.extractXhs(html);
    } catch (e) {
      const fail: WebPageContent = new WebPageContent();
      fail.message = '小红书抓取失败，请检查网络';
      return fail;
    } finally {
      req.destroy();
    }
  }

  // ==================== 小红书专项（参考 collection_ohos） ====================

  /** 是否小红书链接（xhslink 短链在 http 层自动跟随重定向落地） */
  static isXhsUrl(url: string): boolean {
    const u: string = url.toLowerCase();
    return u.indexOf('xiaohongshu.com') >= 0 || u.indexOf('xhslink.com') >= 0;
  }

  /** 美食/做饭相关关键词（宽口径）：命中任一才允许加入笔记 */
  private static readonly FOOD_KEYWORDS: string[] = [
    '菜谱', '食谱', '做饭', '做菜', '烹饪', '厨房', '下厨', '家常菜', '美食',
    '好吃', '吃', '菜', '饭', '汤', '餐', '烘焙', '料理', '食材', '调味',
    '小吃', '早餐', '午餐', '晚餐', '夜宵', '宵夜', '减脂', '煲', '炖', '烧烤'
  ];

  /** 文案是否与美食/做饭相关（宽口径关键词命中） */
  static isFoodRelated(text: string): boolean {
    const t: string = text.toLowerCase();
    for (const kw of WebRecipeImporter.FOOD_KEYWORDS) {
      if (t.indexOf(kw) >= 0) {
        return true;
      }
    }
    return false;
  }

  /**
   * 小红书笔记解析（简化版 collection_ohos XhsNoteParser）：
   * 笔记内容在 window.__INITIAL_STATE__ 的 JSON 里——对反斜杠转义还原后的
   * 原文按 "title"/"desc" 字段正则提取；图片兜底走全页媒体 URL 扫描
   * （collection 的 legacy 通道同款）。
   */
  static extractXhs(html: string): WebPageContent {
    const out: WebPageContent = new WebPageContent();
    // JSON 内 URL 是 \/ 转义，先还原再扫描
    const flat: string = html.replace(/\\\//g, '/');
    const tm: RegExpMatchArray | null = flat.match(/"title":"((?:[^"\\]|\\.)*)"/);
    if (tm !== null) {
      out.title = WebRecipeImporter.decodeJsonString(tm[1]).trim();
    }
    const dm: RegExpMatchArray | null = flat.match(/"desc":"((?:[^"\\]|\\.)*)"/);
    if (dm !== null) {
      out.desc = WebRecipeImporter.decodeJsonString(dm[1]).trim();
    }
    if (out.title.length === 0) {
      out.title = WebRecipeImporter.metaOf(html, ['og:title']);
    }
    if (out.desc.length === 0) {
      out.desc = WebRecipeImporter.metaOf(html, ['og:description']);
    }
    // 图片：优先 sns-img CDN，再通用图片扩展名扫描（跳过头像/图标）
    const urls: string[] = [];
    const push = (u: string): void => {
      if (u.length === 0 || urls.indexOf(u) >= 0 || urls.length >= 9) {
        return;
      }
      const lower: string = u.toLowerCase();
      if (lower.indexOf('avatar') >= 0 || lower.indexOf('icon') >= 0) {
        return;
      }
      urls.push(u);
    };
    const snsRe: RegExp = /https:\/\/sns-img[^"'\s<>\\]+/g;
    let m: RegExpExecArray | null = snsRe.exec(flat);
    while (m !== null && urls.length < 9) {
      push(m[0]);
      m = snsRe.exec(flat);
    }
    const imgRe: RegExp =
      /https?:\/\/[^\s"'<>\\]+?\.(?:jpg|jpeg|png|webp)(?:\?[^\s"'<>\\]*)?/gi;
    m = imgRe.exec(flat);
    while (m !== null && urls.length < 9) {
      push(m[0]);
      m = imgRe.exec(flat);
    }
    out.imageUrls = urls;
    out.text = out.desc;
    out.ok = out.title.length > 0 || out.desc.length > 0 || urls.length > 0;
    if (!out.ok) {
      out.message = '未能解析该小红书笔记（可能需要先在浏览器打开一次）';
    }
    return out;
  }

  /** JSON 字符串内容解码（\n \" \\ \/ \uXXXX） */
  private static decodeJsonString(s: string): string {
    return s
      .replace(/\\n/g, '\n')
      .replace(/\\"/g, '"')
      .replace(/\\\//g, '/')
      .replace(/\\\\/g, '\\')
      .replace(/\\u([0-9a-fA-F]{4})/g, (m: string, p: string): string =>
        String.fromCharCode(parseInt(p, 16)));
  }
}
