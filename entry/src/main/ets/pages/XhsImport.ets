/**
 * 小红书内置浏览器导入（v1.13.4 重构）：
 * 用真实浏览器内核（ArkWeb）加载笔记页——反爬对浏览器环境无效。
 * 关键修复：不再取整个 document.outerHTML（小红书页面 3~5MB，runJavaScript 返回超大
 * 字符串必然被截断/失败 → 解析器拿不到 __INITIAL_STATE__），而是只提取含
 * window.__INITIAL_STATE__ 的那段 <script> 内联文本（通常 100~500KB，正是
 * XhsNoteParser 设计解析的原始数据），失败再回退整个 HTML。
 * 会话 Cookie 与 XhsSession 共享：若页面需要登录/验证，在 WebView 内手动通过，
 * 或点「去小红书登录」走 XhsSession 后再提取即可。
 * 支持 mode=recipe（导入菜谱）/ mode=note（存入笔记）。
 */
import { router, promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { Recipe } from '../model/Models';
import { RecipeParser } from '../service/RecipeParser';
import { DataStore } from '../service/DataStore';
import { WebRecipeImporter } from '../service/WebRecipeImporter';
import { NoteItem } from '../model/Models';
import { NoteStore } from '../service/NoteStore';
import { XhsNoteParser } from '../xhs/XhsNoteParser';
import { XhsUrlParser } from '../xhs/XhsUrlParser';
import { topAvoid } from '../utils/Theme';

const XHS_UA: string =
  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36 xiaohongshu';

/**
 * 只取含 __INITIAL_STATE__ 的 <script> 内联文本（不取整页 outerHTML）。
 * 返回的是脚本内容本身（不含 <script> 标签），解析时再包回 <script>…</script>。
 */
const EXTRACT_STATE_JS: string =
  `(function(){try{var s=document.querySelectorAll('script');` +
  `for(var i=0;i<s.length;i++){var t=s[i].textContent;if(t&&t.indexOf('window.__INITIAL_STATE__')>=0){return t;}}}` +
  `catch(e){}return '';})()`;

/** 回退方案：整页 HTML（体积大，成功率低，但部分笔记可能仍有 state） */
const EXTRACT_OUTER_JS: string = 'document.documentElement.outerHTML';

@Entry
@Component
struct XhsImport {
  private controller: webview.WebviewController = new webview.WebviewController();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  @State url: string = '';
  @State mode: string = 'recipe'; // recipe | note
  @State pageLoaded: boolean = false;
  @State extracting: boolean = false;
  @State showLoginHint: boolean = false;
  @State tip: string = '在下方打开小红书笔记，通过验证后点「提取并导入」';

  aboutToAppear(): void {
    const p: Record<string, Object> = router.getParams() as Record<string, Object>;
    this.url = String(p['url'] ?? '');
    this.mode = (p['mode'] as string) ?? 'recipe';
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: 10 }) {
        Text(this.mode === 'note' ? '导入小红书笔记' : '导入小红书菜谱')
          .fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
        Blank()
        Text('完成')
          .fontSize(15).fontColor($r('app.color.accent'))
          .onClick((): void => {
            router.back();
          })
      }
      .width('100%')
      .padding({ top: topAvoid(this.statusBarHeight) + 8, left: 16, right: 16, bottom: 10 })

      if (this.url.length === 0) {
        Text('缺少链接参数')
          .fontSize(13).fontColor($r('app.color.text_tertiary'))
          .width('100%').padding({ left: 16, right: 16 })
      } else {
        Web({ src: this.url, controller: this.controller })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(false)
          .geolocationAccess(false)
          .onControllerAttached((): void => {
            try {
              // 与解析请求同款 UA：移动端 + xiaohongshu 后缀
              this.controller.setCustomUserAgent(XHS_UA);
            } catch (e) {
            }
          })
          .onPageEnd((): void => {
            this.pageLoaded = true;
            this.showLoginHint = false;
          })
      }

      // 底部操作条
      Column({ space: 8 }) {
        Text(this.tip).fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
        Row({ space: 10 }) {
          Button('重新加载')
            .layoutWeight(1).height(42).borderRadius(21)
            .backgroundColor($r('app.color.page_background'))
            .fontColor($r('app.color.text_primary'))
            .fontSize(14)
            .onClick((): void => {
              this.pageLoaded = false;
              this.showLoginHint = false;
              this.tip = '正在重新加载…';
              try {
                this.controller.refresh();
              } catch (e) {
                this.controller.loadUrl(this.url);
              }
            })
          Button(this.extracting ? '提取中…' : '提取并导入')
            .layoutWeight(2).height(42).borderRadius(21)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .fontSize(14)
            .enabled(this.pageLoaded && !this.extracting)
            .onClick((): void => {
              this.doExtract();
            })
        }
        .width('100%')
        if (this.showLoginHint) {
          Button('去小红书登录 / 获取凭证')
            .width('100%').height(40).borderRadius(20)
            .backgroundColor($r('app.color.page_background'))
            .fontColor($r('app.color.accent'))
            .fontSize(13)
            .onClick((): void => {
              router.pushUrl({ url: 'pages/XhsSession' });
            })
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 12 })
      .backgroundColor($r('app.color.page_background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  /** 在 WebView 内取 __INITIAL_STATE__ 脚本文本（绕过反爬 + 体积小），失败回退整页 HTML */
  private doExtract(): void {
    if (!this.pageLoaded) {
      promptAction.showToast({ message: '页面尚未加载完成' });
      return;
    }
    this.extracting = true;
    this.showLoginHint = false;
    this.tip = '正在从页面提取笔记内容…';
    try {
      this.controller.runJavaScript(EXTRACT_STATE_JS,
        (err: BusinessError, result: string): void => {
          if (err !== null && err.code !== 0) {
            this.fallbackOuter();
            return;
          }
          const raw: string = result ?? '';
          if (raw.length >= 50 && raw.indexOf('window.__INITIAL_STATE__') >= 0) {
            this.onHtml(raw);
          } else {
            // 没取到 state（可能是验证页），回退整页 HTML 再试一次
            this.fallbackOuter();
          }
        });
    } catch (e) {
      this.fallbackOuter();
    }
  }

  /** 回退：取整个 outerHTML 交给解析器（体积大，作为兜底） */
  private fallbackOuter(): void {
    try {
      this.controller.runJavaScript(EXTRACT_OUTER_JS,
        (err: BusinessError, result: string): void => {
          if (err !== null && err.code !== 0) {
            promptAction.showToast({ message: `提取失败：${err.message}` });
            this.extracting = false;
            return;
          }
          this.onHtml(result ?? '');
        });
    } catch (e) {
      promptAction.showToast({ message: `提取异常：${(e as Error).message}` });
      this.extracting = false;
    }
  }

  private onHtml(raw: string): void {
    let parseInput: string = raw;
    // runJavaScript 返回的是 <script> 内联文本（不含标签），包回 <script>…</script> 供解析器定位
    if (raw.indexOf('<') < 0 && raw.indexOf('window.__INITIAL_STATE__') >= 0) {
      parseInput = '<script>' + raw + '</script>';
    }
    if (parseInput.length < 50) {
      this.tip = '未读到笔记内容：请先在该页面内登录小红书 / 通过验证，再点「提取并导入」';
      this.showLoginHint = true;
      this.extracting = false;
      return;
    }
    const noteId: string = XhsUrlParser.extractPostId(this.url);
    const note = new XhsNoteParser().parse(parseInput, noteId, this.url);
    if (note.title.length === 0 && note.description.length === 0 && note.mediaUrls.length === 0) {
      this.tip = '未能从页面提取到笔记内容：请确认笔记已打开，或先登录 / 通过验证后重试';
      this.showLoginHint = true;
      this.extracting = false;
      return;
    }
    if (this.mode === 'note') {
      this.buildNote(note.title, note.description, note.mediaUrls, note.userName);
    } else {
      this.buildRecipe(note.title, note.description, note.mediaUrls);
    }
  }

  /** 导入菜谱：标题+正文 → RecipeParser → 下配图 → 入库 */
  private async buildRecipe(title: string, desc: string, mediaUrls: string[]): Promise<void> {
    const fullText: string = (title.length > 0 ? title + '\n\n' : '') + desc;
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const locals: string[] = [];
    for (const u of mediaUrls) {
      if (locals.length >= 3) {
        break;
      }
      if (u.toLowerCase().indexOf('.mp4') >= 0 || u.toLowerCase().indexOf('.mov') >= 0) {
        continue;
      }
      if (!u.startsWith('http')) {
        continue;
      }
      const p: string = await WebRecipeImporter.downloadImage(ctx, u);
      if (p.length > 0) {
        locals.push(p);
      }
    }
    const recipe: Recipe = RecipeParser.parse(fullText, title.length > 0 ? title : '小红书菜谱');
    if (locals.length > 0) {
      recipe.cover = locals[0];
      if (locals.length > 1) {
        recipe.images = locals.slice(1);
      }
    }
    recipe.source = '小红书';
    recipe.sourceText = this.url;
    DataStore.saveRecipe(recipe);
    promptAction.showToast({
      message: `已导入：${recipe.name}（${recipe.ingredients.length}种食材 / ${recipe.steps.length}步${locals.length > 0 ? ` / ${locals.length}张配图` : ''}）`
    });
    router.back();
  }

  /** 存入笔记：文本 + 配图（最多 9 张） */
  private async buildNote(title: string, desc: string, mediaUrls: string[], author: string): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const locals: string[] = [];
    for (const u of mediaUrls) {
      if (locals.length >= 9) {
        break;
      }
      if (u.toLowerCase().indexOf('.mp4') >= 0 || u.toLowerCase().indexOf('.mov') >= 0) {
        continue;
      }
      if (!u.startsWith('http')) {
        continue;
      }
      const p: string = await WebRecipeImporter.downloadImage(ctx, u);
      if (p.length > 0) {
        locals.push(p);
      }
    }
    const n: NoteItem = new NoteItem();
    n.id = `n${Date.now()}`;
    const head: string = title.length > 0 ? `${title}${author.length > 0 ? `（@${author}）` : ''}\n` : '';
    n.text = `${head}${desc}`.trim();
    n.mediaPaths = locals.slice();
    n.time = Date.now();
    n.source = '小红书';
    if (locals.length > 0) {
      try {
        const src: image.ImageSource = await image.createImageSource(locals[0]);
        const info: image.ImageInfo = await src.getImageInfo();
        await src.release();
        if (info.size.width > 0 && info.size.height > 0) {
          n.coverW = info.size.width;
          n.coverH = info.size.height;
        }
      } catch (e) {
      }
    }
    NoteStore.save(n);
    promptAction.showToast({ message: '已加入笔记' });
    router.back();
  }
}
