/**
 * 解析链接加入笔记（v1.12.1）：
 * 粘贴小红书/下厨房等帖子链接 → 抓取解析 → 美食相关校验（小红书强过滤，
 * 与做饭无关的内容不加入）→ 配图下载到本地 → 存为笔记进瀑布流。
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { NoteItem } from '../model/Models';
import { NoteStore } from '../service/NoteStore';
import { WebRecipeImporter, WebPageContent } from '../service/WebRecipeImporter';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct NoteImport {
  private scroller: Scroller = new Scroller();
  @State urlInput: string = '';
  @State parsing: boolean = false;
  /** 解析结果预览 */
  @State previewTitle: string = '';
  @State previewDesc: string = '';
  @State previewImages: string[] = [];
  @State previewSource: string = '';

  private parse(): void {
    const url: string = WebRecipeImporter.normalizeUrl(this.urlInput);
    if (url.length === 0) {
      promptAction.showToast({ message: '请先粘贴帖子链接' });
      return;
    }
    this.parsing = true;
    this.previewTitle = '';
    this.previewDesc = '';
    this.previewImages = [];
    const isXhs: boolean = WebRecipeImporter.isXhsUrl(url);
    WebRecipeImporter.fetchPage(url).then(async (page: WebPageContent): Promise<void> => {
      if (!page.ok) {
        promptAction.showToast({ message: page.message });
        this.parsing = false;
        return;
      }
      let content: WebPageContent = page;
      // 小红书专项提取（INITIAL_STATE JSON：标题/正文/sns-img 图组）
      if (isXhs) {
        content = await WebRecipeImporter.fetchXhs(url);
        if (!content.ok) {
          promptAction.showToast({ message: content.message });
          this.parsing = false;
          return;
        }
      }
      // 小红书强过滤：文案必须与美食/做饭相关（宽口径），否则拒收
      if (isXhs && !WebRecipeImporter.isFoodRelated(`${content.title} ${content.desc}`)) {
        promptAction.showToast({ message: '该笔记与美食/做饭无关，未加入笔记' });
        this.parsing = false;
        return;
      }
      // 下载配图到本地（最多 9 张）
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const locals: string[] = [];
      for (const u of content.imageUrls) {
        if (locals.length >= 9) {
          break;
        }
        const p: string = await WebRecipeImporter.downloadImage(ctx, u);
        if (p.length > 0) {
          locals.push(p);
        }
      }
      this.previewTitle = content.title;
      this.previewDesc = content.desc;
      this.previewImages = locals;
      this.previewSource = isXhs ? '小红书' : '网页';
      this.parsing = false;
    });
  }

  private async saveNote(): Promise<void> {
    if (this.previewTitle.length === 0 && this.previewDesc.length === 0 && this.previewImages.length === 0) {
      promptAction.showToast({ message: '请先解析链接' });
      return;
    }
    const n: NoteItem = new NoteItem();
    n.id = `n${Date.now()}`;
    const head: string = this.previewTitle.length > 0 ? `${this.previewTitle}\n` : '';
    n.text = `${head}${this.previewDesc}`.trim();
    n.mediaPaths = this.previewImages.slice();
    n.time = Date.now();
    n.source = this.previewSource.length > 0 ? this.previewSource : '网页';
    if (n.mediaPaths.length > 0) {
      try {
        const src: image.ImageSource = await image.createImageSource(n.mediaPaths[0]);
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

  build() {
    Stack() {
      FrostPage({ title: '解析链接', subtitle: '小红书 · 下厨房等帖子存入笔记', scroller: this.scroller }) {
        Column({ space: 14 }) {
          TextInput({ placeholder: '粘贴分享链接（小红书 / 下厨房等）', text: this.urlInput })
            .width('100%')
            .height(44).fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .onChange((v: string): void => {
              this.urlInput = v;
            })

          Button(this.parsing ? '解析中…' : '解析')
            .width('100%')
            .height(44).borderRadius(22)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .fontSize(15)
            .enabled(!this.parsing)
            .onClick((): void => {
              this.parse();
            })

          Text('小红书帖子仅收录与美食/做饭相关的文案内容，无关内容不会加入')
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')

          // 解析结果预览
          if (this.previewTitle.length > 0 || this.previewDesc.length > 0 || this.previewImages.length > 0) {
            Column({ space: 10 }) {
              Row() {
                Text(this.previewSource).fontSize(10).fontColor($r('app.color.accent'))
                  .backgroundColor($r('app.color.accent_soft'))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(9)
                Blank()
              }
              .width('100%')
              if (this.previewTitle.length > 0) {
                Text(this.previewTitle)
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                  .width('100%')
              }
              if (this.previewDesc.length > 0) {
                Text(this.previewDesc)
                  .fontSize(13).lineHeight(20).fontColor($r('app.color.text_secondary'))
                  .maxLines(8).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              if (this.previewImages.length > 0) {
                Row({ space: 6 }) {
                  ForEach(this.previewImages.slice(0, 4), (p: string): void => {
                    Image(p.startsWith('/') ? `file://${p}` : p)
                      .width(72)
                      .height(72)
                      .borderRadius(8)
                      .objectFit(ImageFit.Cover)
                      .backgroundColor($r('app.color.page_background'))
                  }, (p: string): string => p)
                  if (this.previewImages.length > 4) {
                    Text(`+${this.previewImages.length - 4}`)
                      .fontSize(12).fontColor($r('app.color.text_tertiary'))
                  }
                }
                .width('100%')
              }
              Button('保存到笔记')
                .width('100%')
                .height(42).borderRadius(21)
                .backgroundColor($r('app.color.accent'))
                .fontColor(Color.White)
                .fontSize(14)
                .onClick((): void => {
                  this.saveNote();
                })
            }
            .width('100%').padding(14).borderRadius(14)
            .backgroundColor($r('app.color.card_background'))
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
    }
  }
}
