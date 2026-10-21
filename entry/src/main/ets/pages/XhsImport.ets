/**
 * 小红书内置浏览器导入（v1.13.3 重构）：
 * 之前 app 用 http 直连小红书被反爬拦截（返回验证页/空页）→ 永远「网页抓取失败」。
 * 改为用真实浏览器内核（ArkWeb）加载笔记页，在页面内取渲染后的完整 DOM/HTML，
 * 复用现有 XhsNoteParser（收藏同款 INITIAL_STATE 深挖）解析，绕过反爬；
 * 会话 Cookie 与 XhsSession 共享，登录/验证在 WebView 内手动通过后即可提取。
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

/** 在页面内取完整 HTML（含 window.__INITIAL_STATE__ 脚本），供解析器深挖 */
const EXTRACT_HTML_JS: string = 'document.documentElement.outerHTML';

@Entry
@Component
struct XhsImport {
  private controller: webview.WebviewController = new webview.WebviewController();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  @State url: string = '';
  @State mode: string = 'recipe'; // recipe | note
  @State pageLoaded: boolean = false;
  @State extracting: boolean = false;
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
      }
      .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 12 })
      .backgroundColor($r('app.color.page_background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  /** 在 WebView 内取渲染后的 HTML，复用 XhsNoteParser 解析（绕过反爬） */
  private doExtract(): void {
    if (!this.pageLoaded) {
      promptAction.showToast({ message: '页面尚未加载完成' });
      return;
    }
    this.extracting = true;
    this.tip = '正在从页面提取笔记内容…';
    try {
      this.controller.runJavaScript(EXTRACT_HTML_JS,
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

  private onHtml(html: string): void {
    if (html.length < 200) {
      this.tip = '未取到页面内容，请确认笔记已打开并通过验证后重试';
      this.extracting = false;
      return;
    }
    const noteId: string = XhsUrlParser.extractPostId(this.url);
    const note = new XhsNoteParser().parse(html, noteId, this.url);
    if (note.title.length === 0 && note.description.length === 0 && note.mediaUrls.length === 0) {
      this.tip = '未能从页面提取到笔记内容，请在 WebView 内通过验证/打开笔记后重新点「提取」';
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
    const fullText: string = `${title}\n\n${desc.length > 0 ? desc + '\n\n' : ''}${desc}`;
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
