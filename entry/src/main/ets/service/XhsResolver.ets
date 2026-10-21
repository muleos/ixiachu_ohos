/**
 * 小红书解析器（v1.12.9）—— 照搬 collection_ohos 解析链路：
 * 1. XhsUrlParser 从分享文本提链 / 识别短链 / 提取 noteId；
 * 2. fetchHtml 手动跟随 3xx 重定向链（最多 5 跳），UA 带小红书后缀，
 *    自动携带应用内 WebView 会话 Cookie（useWebSession 同款），禁缓存；
 * 3. XhsNoteParser 深挖 __INITIAL_STATE__（标题/正文/图组/live-photo/视频），
 *    兜底全页媒体 URL 扫描；
 * 4. 错误页识别：小红书 404/权限拦截页不作为解析结果，抛出明确原因
 *    （笔记已删除 / 需要访问凭证），由页面引导获取凭证。
 */
import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { ParsedXhsNote } from '../xhs/XhsNoteParser';
import { XhsNoteParser } from '../xhs/XhsNoteParser';
import { XhsUrlParser } from '../xhs/XhsUrlParser';

const TAG: string = 'XhsResolver';
const MAX_HOPS: number = 5;

/** 错误页判定结果：精确文案 + 是否「需要访问凭证」 */
interface XhsErrorReason {
  message: string;
  credential: boolean;
}

export class XhsResolver {
  /** 与收藏/安卓端一致：移动 Chrome UA + xiaohongshu 后缀 */
  private static readonly UA: string =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36 xiaohongshu';

  /** 从分享文本/链接解析笔记（可能包含多余文案，自动提链；短链自动跳转） */
  static async resolve(rawInput: string): Promise<ParsedXhsNote> {
    const links: string[] = XhsUrlParser.extractLinks(rawInput);
    if (links.length === 0) {
      throw new XhsResolveError('未在输入中识别到小红书链接（需包含 xiaohongshu.com 或 xhslink.com）', false);
    }
    let lastError: string = '解析失败';
    let lastCredential: boolean = false;
    for (const link of links) {
      const url: string = XhsUrlParser.normalizeUrl(link);
      const noteId: string = XhsUrlParser.extractPostId(url);
      try {
        const html: string = await XhsResolver.fetchHtmlFollow(url, MAX_HOPS);
        const parsed: ParsedXhsNote = new XhsNoteParser().parse(html, noteId, url);
        // 错误页识别：小红书拦截/404 页不作为结果，并区分「需凭证」与「已删除/失效」
        const reason: XhsErrorReason | null = XhsResolver.errorPageReason(parsed);
        if (reason !== null) {
          lastError = reason.message;
          lastCredential = reason.credential;
          continue;
        }
        if (parsed.title.length > 0 || parsed.description.length > 0 || parsed.mediaUrls.length > 0) {
          return parsed;
        }
        lastError = '未能从页面提取到笔记内容（页面可能未完整加载）';
        lastCredential = false;
      } catch (e) {
        const m: string = (e as Error).message ?? '网络错误';
        lastError = m;
        lastCredential = m.indexOf('需要访问凭证') >= 0 || m.indexOf('凭证') >= 0;
      }
    }
    throw new XhsResolveError(lastError, lastCredential);
  }

  /**
   * 小红书错误页识别（标题与正文关键词）。
   * 返回 null 表示不是错误页；否则给出精确文案与是否「需要访问凭证」：
   * - 笔记已删除/链接失效：无需引导获取凭证；
   * - 访问受限/加载失败：多为风控或登录墙，引导获取凭证重试。
   */
  private static errorPageReason(parsed: ParsedXhsNote): XhsErrorReason | null {
    const text: string = `${parsed.title} ${parsed.description}`;
    const markers: string[] = ['页面不见', '页面不存在', '笔记不存在', '加载失败', '访问出错', '暂时无法浏览'];
    let hit: boolean = false;
    for (const m of markers) {
      if (text.indexOf(m) >= 0) {
        hit = true;
        break;
      }
    }
    if (!hit) {
      return null;
    }
    // 已删除/失效：不引导获取凭证（凭证救不回已删的笔记）
    if (text.indexOf('笔记不存在') >= 0 || text.indexOf('页面不存在') >= 0 || text.indexOf('页面不见') >= 0) {
      return { message: '该笔记可能已删除或链接已失效，小红书返回了错误页', credential: false };
    }
    // 其余（加载失败/访问出错/暂时无法浏览）：多为访问受限，引导凭证
    return { message: '该笔记需要访问凭证（请先点下方按钮获取凭证再重试）', credential: true };
  }

  /** GET 页面文本：与收藏 XhsHttpClient.fetchHtml 一致——UA 带 xiaohongshu 后缀 +
   *  WebView 共享会话 Cookie（按 host 取）+ 依赖 http 默认自动跟随 3xx 重定向
   *  + 不设 expectDataType（避免 gzip 响应在部分情况下被解析成空串，收藏即如此）。 */
  private static async fetchHtmlFollow(url: string, maxHops: number): Promise<string> {
    const resp: XhsResponse = await XhsResolver.fetchOnce(url);
    if (resp.isRedirect) {
      if (maxHops <= 0 || resp.location.length === 0) {
        throw new Error('重定向次数过多');
      }
      const next: string = XhsResolver.absoluteUrl(url, resp.location);
      return XhsResolver.fetchHtmlFollow(next, maxHops - 1);
    }
    if (resp.text.length < 50) {
      throw new Error('页面内容为空（可能触发了访问验证，请先获取访问凭证后重试）');
    }
    return resp.text;
  }

  private static fetchOnce(url: string): Promise<XhsResponse> {
    return new Promise<XhsResponse>((resolve: (v: XhsResponse) => void, reject: (e: Error) => void): void => {
      const req: http.HttpRequest = http.createHttp();
      const header: Record<string, string> = {
        'User-Agent': XhsResolver.UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9'
      };
      // 会话 Cookie：与收藏 XhsHttpClient.cookieHeaderFor 一致，按 host 取 WebView 共享 cookie 桶
      const cookie: string = XhsResolver.cookieForUrl(url);
      if (cookie.length > 0) {
        header['Cookie'] = cookie;
      }
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: header,
        connectTimeout: 15000,
        readTimeout: 20000,
        usingCache: false
      };
      req.request(url, options).then((resp: http.HttpResponse): void => {
        try {
          const code: number = resp.responseCode;
          const text: string = typeof resp.result === 'string' ? resp.result as string : '';
          if (code >= 300 && code < 400) {
            const locRaw: Object | undefined = (resp.header as Record<string, Object>)['location'];
            const loc: string = locRaw !== undefined ? String(locRaw) : '';
            resolve(new XhsResponse(true, loc, ''));
            return;
          }
          if (code >= 200 && code < 400 && text.length > 0) {
            resolve(new XhsResponse(false, '', text));
            return;
          }
          const cred: boolean = code === 401 || code === 403;
          reject(new Error(`小红书返回 HTTP ${code}${cred ? '（需要访问凭证）' : (code === 404 ? '（链接可能已失效）' : '')}`));
        } finally {
          req.destroy();
        }
      }).catch((err: Error): void => {
        req.destroy();
        reject(new Error(err.message ?? '网络错误，请检查网络'));
      });
    });
  }

  /** 与收藏 XhsHttpClient.cookieHeaderFor 一致：仅对小红书/rednote 域注入会话 Cookie（按 host 取） */
  private static cookieForUrl(url: string): string {
    if (!url.startsWith('https://')) {
      return '';
    }
    if (url.indexOf('xiaohongshu.com') >= 0 || url.indexOf('rednote.com') >= 0 || url.indexOf('xhslink.com') >= 0) {
      const hosts: string[] = ['https://www.xiaohongshu.com', 'https://www.rednote.com'];
      for (const h of hosts) {
        try {
          const c: string = webview.WebCookieManager.fetchCookieSync(h) ?? '';
          if (c.length > 0) {
            return c;
          }
        } catch (e) {
          // 忽略，尝试下一个 host
        }
      }
    }
    return '';
  }

  /** 相对 Location 转绝对 URL */
  private static absoluteUrl(base: string, location: string): string {
    if (location.startsWith('http://') || location.startsWith('https://')) {
      return location;
    }
    const m: RegExpMatchArray | null = base.match(/^(https?:\/\/[^/?#]+)/i);
    const origin: string = m !== null ? m[1] : '';
    if (location.startsWith('/')) {
      return origin + location;
    }
    return `${origin}/${location}`;
  }
}

/** 单次请求结果：重定向（含 Location）或最终文本 */
class XhsResponse {
  isRedirect: boolean;
  location: string;
  text: string;

  constructor(isRedirect: boolean, location: string, text: string) {
    this.isRedirect = isRedirect;
    this.location = location;
    this.text = text;
  }
}

/** 解析失败错误：携带是否「需要访问凭证」，供页面决定引导策略（避免误引导） */
export class XhsResolveError extends Error {
  needCredential: boolean;

  constructor(message: string, needCredential: boolean) {
    super(message);
    this.name = 'XhsResolveError';
    this.needCredential = needCredential;
  }
}
