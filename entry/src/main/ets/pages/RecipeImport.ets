/**
 * 导入菜谱（v1.11.0）：
 * ① 手动创建（表单式）；
 * ② 网页链接导入 —— 粘贴下厨房/小红书/微博等帖子链接，抓取网页自动生成菜谱，
 *    相关图片一并下载随菜谱保存（替代原下厨房专用 API，全平台通用）；
 * ③ 粘贴文字版菜谱 → 自动识别食材/做法/营养热量。
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Recipe } from '../model/Models';
import { RecipeParser } from '../service/RecipeParser';
import { DataStore } from '../service/DataStore';
import { WebRecipeImporter, WebPageContent } from '../service/WebRecipeImporter';
import { FrostPage } from '../components/FrostPage';

const SAMPLE: string = `番茄炒蛋（2人份）

食材：
番茄 2个
鸡蛋 3个
小葱 2根
盐 3克
糖 5克
油 20ml

做法：
1. 番茄切块，鸡蛋打散加少许盐。
2. 热锅下油，倒入蛋液炒至凝固盛出。
3. 锅中留油，下番茄炒出汁水。
4. 倒回鸡蛋，加盐和糖翻炒均匀，撒葱花出锅。`;

@Entry
@Component
struct RecipeImport {
  private scroller: Scroller = new Scroller();
  @State text: string = '';
  @State urlInput: string = '';
  @State importing: boolean = false;
  /** 网页解析成功但识别不全时，暂存已下载图片，等「识别并入库」一起落 */
  @State pendingCover: string = '';
  @State pendingImages: string[] = [];

  build() {
    Stack() {
      FrostPage({ title: '导入菜谱', scroller: this.scroller }) {
        Column({ space: 14 }) {
          // ⓪ 手动创建（表单式）
          Row({ space: 12 }) {
            Column({ space: 3 }) {
              Text('手动创建菜谱').fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text('封面图 · 风味标签 · 食材清单 · 分步做法').fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(15).fontColor([$r('app.color.text_tertiary')])
          }
          .width('100%').padding(16).borderRadius(16)
          .backgroundColor($r('app.color.accent_soft'))
          .onClick((): void => {
            router.pushUrl({ url: 'pages/RecipeManual' });
          })

          // ① 网页链接导入（下厨房/小红书/微博等帖子）
          Column({ space: 10 }) {
            Text('网页链接导入').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              .width('100%')
            TextInput({
              placeholder: '粘贴菜谱帖子链接（下厨房 / 小红书 / 微博等）',
              text: this.urlInput
            })
              .width('100%')
              .height(40).fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((v: string): void => {
                this.urlInput = v;
              })
            Button(this.importing ? '解析中…' : '解析网页并导入')
              .width('100%').height(40).borderRadius(20)
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .enabled(!this.importing)
              .onClick((): void => {
                this.doWebImport();
              })
            Text('自动读取网页标题、正文与配图生成菜谱；脚本渲染/需登录的页面可能提取不全，可在下方文本框手动修正')
              .fontSize(11).fontColor($r('app.color.text_tertiary'))
          }
          .width('100%').padding(16).borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .alignItems(HorizontalAlign.Start)

          // ② 文字粘贴识别
          Column({ space: 8 }) {
            Text('粘贴文字版菜谱').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              .width('100%')
            TextArea({
              placeholder: '支持「食材/用料」与「做法/步骤」分段，\n自动识别菜名、食材用量、营养价值与热量估算。\n网页解析结果也会回填到这里，可手动修正。',
              text: this.text
            })
              .width('100%')
              .height(180)
              .padding(14)
              .borderRadius(12)
              .backgroundColor($r('app.color.page_background'))
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .onChange((v: string): void => {
                this.text = v;
              })
            Row({ space: 12 }) {
              Button('填入示例')
                .layoutWeight(1).height(42).borderRadius(21)
                .backgroundColor($r('app.color.page_background'))
                .fontColor($r('app.color.text_secondary'))
                .onClick((): void => {
                  this.text = SAMPLE;
                })
              Button('识别并入库')
                .layoutWeight(2).height(42).borderRadius(21)
                .backgroundColor($r('app.color.accent'))
                .fontColor(Color.White)
                .onClick((): void => {
                  this.saveFromText();
                })
            }
            .width('100%')
          }
          .width('100%').padding(16).borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 网页链接导入：抓取 → 解析 → 下载配图 → 入库（识别不全则回填文本待修正） */
  private async doWebImport(): Promise<void> {
    const url: string = WebRecipeImporter.normalizeUrl(this.urlInput);
    if (url.length === 0) {
      promptAction.showToast({ message: '请先粘贴网页链接' });
      return;
    }
    this.importing = true;
    try {
      // 小红书链接交给内置浏览器解析页（绕过反爬，复用 XhsNoteParser）
      if (WebRecipeImporter.isXhsUrl(url)) {
        router.pushUrl({ url: 'pages/XhsImport', params: { url: url, mode: 'recipe' } });
        this.importing = false;
        return;
      }
      const page: WebPageContent = await WebRecipeImporter.fetchPage(url);
      if (!page.ok) {
        promptAction.showToast({ message: page.message });
        if (page.text.length > 0) {
          this.text = page.text;
        }
        this.importing = false;
        return;
      }
      await this.finishImport(page, url);
    } catch (e) {
      promptAction.showToast({ message: `导入失败：${(e as Error).message}` });
    }
    this.importing = false;
  }

  /** 网页解析成功后的统一流程：回填文本 → 下配图 → 识别入库 */
  private async finishImport(page: WebPageContent, url: string): Promise<void> {
    // 组装解析文本：标题 + 描述 + 正文（菜名取标题）
    const fullText: string =
      `${page.title}\n\n${page.desc.length > 0 ? page.desc + '\n\n' : ''}${page.text}`;
    this.text = fullText;

    // 下载配图（最多 3 张随菜谱保存）
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const locals: string[] = [];
    for (const u of page.imageUrls) {
      if (locals.length >= 3) {
        break;
      }
      const p: string = await WebRecipeImporter.downloadImage(ctx, u);
      if (p.length > 0) {
        locals.push(p);
      }
    }
    this.pendingCover = locals.length > 0 ? locals[0] : '';
    this.pendingImages = locals.slice(1);

    const recipe: Recipe = RecipeParser.parse(fullText, page.title.length > 0 ? page.title : '网页菜谱');
    if (recipe.ingredients.length === 0 && recipe.steps.length === 0) {
      promptAction.showToast({
        message: '已抓取内容并填入文本框，自动识别不全，请修正「食材/做法」分段后点「识别并入库」'
      });
      this.importing = false;
      return;
    }
    this.applyWebMeta(recipe, url);
    DataStore.saveRecipe(recipe);
    promptAction.showToast({
      message: `已导入：${recipe.name}（${recipe.ingredients.length}种食材 / ${recipe.steps.length}步${locals.length > 0 ? ` / ${locals.length}张配图` : ''}）`
    });
    router.back();
  }

  /** 文本识别入库（携带网页阶段暂存的配图） */
  private saveFromText(): void {
    if (this.text.trim().length < 10) {
      promptAction.showToast({ message: '请先粘贴菜谱文本' });
      return;
    }
    let recipe: Recipe;
    try {
      recipe = RecipeParser.parse(this.text, '未命名菜谱');
    } catch (e) {
      promptAction.showToast({ message: '解析异常，请修正文本分段后重试' });
      return;
    }
    if (recipe.ingredients.length === 0 && recipe.steps.length === 0) {
      promptAction.showToast({ message: '未能识别出食材或步骤，请保留「食材：」「做法：」分段后重试' });
      return;
    }
    this.applyWebMeta(recipe, '');
    DataStore.saveRecipe(recipe);
    promptAction.showToast({
      message: `已识别：${recipe.name}（${recipe.ingredients.length}种食材 / ${recipe.steps.length}步）`
    });
    router.back();
  }

  private applyWebMeta(recipe: Recipe, url: string): void {
    if (this.pendingCover.length > 0) {
      recipe.cover = this.pendingCover;
    }
    if (this.pendingImages.length > 0) {
      recipe.images = this.pendingImages.slice();
    }
    if (url.length > 0) {
      recipe.source = '网页导入';
      recipe.sourceText = url;
    }
    this.pendingCover = '';
    this.pendingImages = [];
  }
}
