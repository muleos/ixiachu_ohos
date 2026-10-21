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

export class XhsResolver {
  /** 与收藏/安卓端一致：移动 Chrome UA + xiaohongshu 后缀 */
  private static readonly UA: string =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36 xiaohongshu';

  /** 从分享文本/链接解析笔记（可能包含多余文案，自动提链；短链自动跳转） */
  static async resolve(rawInput: string): Promise<ParsedXhsNote> {
    const links: string[] = XhsUrlParser.extractLinks(rawInput);
    if (links.length === 0) {
      throw new Error('未在输入中识别到小红书链接（需包含 xiaohongshu.com 或 xhslink.com）');
    }
    let lastError: string = '解析失败';
    for (const link of links) {
      const url: string = XhsUrlParser.normalizeUrl(link);
      const noteId: string = XhsUrlParser.extractPostId(url);
      try {
        const html: string = await XhsResolver.fetchHtmlFollow(url, MAX_HOPS);
        const parsed: ParsedXhsNote = new XhsNoteParser().parse(html, noteId, url);
        // 错误页识别：小红书拦截/404 页不作为结果
        if (XhsResolver.isErrorPage(parsed)) {
          lastError = '链接返回了小红书错误页：笔记可能已删除/仅自己可见，或需要访问凭证（先点下方按钮获取凭证再重试）';
          continue;
        }
        if (parsed.title.length > 0 || parsed.description.length > 0 || parsed.mediaUrls.length > 0) {
          return parsed;
        }
        lastError = '未能从页面提取到笔记内容';
      } catch (e) {
        lastError = (e as Error).message ?? '网络错误';
      }
    }
    throw new Error(lastError);
  }

  /** 小红书拦截/错误页识别（标题与正文关键词） */
  private static isErrorPage(parsed: ParsedXhsNote): boolean {
    const text: string = `${parsed.title} ${parsed.description}`;
    const markers: string[] = ['页面不见', '页面不存在', '笔记不存在', '加载失败', '访问出错', '暂时无法浏览'];
    for (const m of markers) {
      if (text.indexOf(m) >= 0) {
        return true;
      }
    }
    return false;
  }

  /** GET 页面文本，手动跟随 3xx 重定向（最多 maxHops 跳），自动携带会话 Cookie */
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
      throw new Error('页面内容为空');
    }
    return resp.text;
  }

  private static fetchOnce(url: string): Promise<XhsResponse> {
    return new Promise<XhsResponse>((resolve: (v: XhsResponse) => void, reject: (e: Error) => void): void => {
      const req: http.HttpRequest = http.createHttp();
      // 会话 Cookie（收藏 useWebSession 同款）：应用内 WebView 访问过小红书即自动携带
      const header: Record<string, string> = {
        'User-Agent': XhsResolver.UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9'
      };
      if (url.startsWith('https://')) {
        try {
          const cookie: string = webview.WebCookieManager.fetchCookieSync(url) ?? '';
          if (cookie.length > 0) {
            header['Cookie'] = cookie;
          }
        } catch (e) {
          // 无会话则匿名访问
        }
      }
      req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 20000,
        header: header,
        usingCache: false,
        expectDataType: http.HttpDataType.STRING
      }).then((resp: http.HttpResponse): void => {
        try {
          const code: number = resp.responseCode;
          if (code >= 300 && code < 400) {
            const locRaw: Object | undefined = (resp.header as Record<string, Object>)['location'];
            const loc: string = locRaw !== undefined ? String(locRaw) : '';
            resolve(new XhsResponse(true, loc, ''));
            return;
          }
          if (code < 200 || code >= 300) {
            reject(new Error(`小红书返回 HTTP ${code}${code === 404 ? '（链接可能已失效）' : ''}`));
            return;
          }
          const text: string = typeof resp.result === 'string' ? resp.result : '';
          resolve(new XhsResponse(false, '', text));
        } finally {
          req.destroy();
        }
      }).catch((err: Error): void => {
        req.destroy();
        reject(new Error(err.message ?? '网络错误，请检查网络'));
      });
    });
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
