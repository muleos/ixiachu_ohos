/**
 * 小红书解析器（v1.12.3）—— 完整移植 collection_ohos 解析内核：
 * XhsUrlParser（分享文本提链/短链识别/noteId）+ XhsNoteParser
 * （__INITIAL_STATE__ JSON 深挖：标题/正文/图组/live-photo/视频，兜底
 * 全页媒体 URL 扫描）。HTTP 层用收藏同款 UA（xiaohongshu 后缀），
 * 短链跟随重定向后按单笔记对象解析。
 */
import { http } from '@kit.NetworkKit';
import { ParsedXhsNote } from '../xhs/XhsNoteParser';
import { XhsNoteParser } from '../xhs/XhsNoteParser';
import { XhsUrlParser } from '../xhs/XhsUrlParser';

const DOMAIN: number = 0x1CA;
const TAG: string = 'XhsResolver';

export class XhsResolver {
  /** 与收藏/安卓端一致：移动 Chrome UA + xiaohongshu 后缀 */
  private static readonly UA: string =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36 xiaohongshu';

  /** 从分享文本/链接解析笔记（可能包含多余文案，自动提链；短链自动跳转） */
  static async resolve(rawInput: string): Promise<ParsedXhsNote> {
    const links: string[] = XhsUrlParser.extractLinks(rawInput);
    if (links.length === 0) {
      throw new Error('未在输入中识别到小红书链接');
    }
    let lastError: string = '解析失败';
    for (const link of links) {
      const url: string = XhsUrlParser.normalizeUrl(link);
      try {
        const html: string = await XhsResolver.fetchHtml(url);
        const noteId: string = XhsUrlParser.extractPostId(url);
        const parsed: ParsedXhsNote = new XhsNoteParser().parse(html, noteId, url);
        if (parsed.title.length > 0 || parsed.description.length > 0 || parsed.mediaUrls.length > 0) {
          return parsed;
        }
        lastError = '未能提取到笔记内容';
      } catch (e) {
        lastError = (e as Error).message ?? '网络错误';
      }
    }
    throw new Error(`解析失败：${lastError}`);
  }

  private static fetchHtml(url: string): Promise<string> {
    return new Promise<string>((resolve: (v: string) => void, reject: (e: Error) => void): void => {
      const req: http.HttpRequest = http.createHttp();
      req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 20000,
        header: {
          'User-Agent': XhsResolver.UA,
          'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8'
        },
        expectDataType: http.HttpDataType.STRING
      }).then((resp: http.HttpResponse): void => {
        try {
          if (resp.responseCode !== 200) {
            reject(new Error(`小红书返回 ${resp.responseCode}`));
            return;
          }
          const html: string = typeof resp.result === 'string' ? resp.result : '';
          if (html.length < 50) {
            reject(new Error('页面内容为空'));
            return;
          }
          resolve(html);
        } finally {
          req.destroy();
        }
      }).catch((err: Error): void => {
        req.destroy();
        reject(new Error(err.message ?? '网络错误'));
      });
    });
  }
}
