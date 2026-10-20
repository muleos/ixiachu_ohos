/**
 * 菜单图片识别：拍菜单 / 相册选图 → 系统文字识别（Core Vision Kit）
 * → 复用菜谱文本解析（菜名 / 食材用量 / 步骤 / 营养热量）→ 入库菜单库。
 * v1.10.0：官方沉浸光感顶栏；拍照/相册双入口（此前按钮写「拍」实际只开相册）；
 * 识别后即时解析预览（菜名/食材/步数/热量）；提供手动创建入口。
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Recipe } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { RecipeParser } from '../service/RecipeParser';
import { ReceiptParser } from '../service/ReceiptParser';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct MenuScan {
  private scroller: Scroller = new Scroller();
  @State rawText: string = '';
  @State scanning: boolean = false;

  /** 识别文本的即时解析预览（空文本返回 null） */
  private preview(): Recipe | null {
    if (this.rawText.trim().length < 10) {
      return null;
    }
    return RecipeParser.parse(this.rawText, '未命名菜谱');
  }

  build() {
    Stack() {
    FrostPage({ title: '菜单图片识别', scroller: this.scroller }) {
      Column({ space: 14 }) {
        // 识别入口
        Row({ space: 12 }) {
          Button(this.scanning ? '识别中…' : '拍菜单')
            .layoutWeight(1).height(44).borderRadius(22)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .fontSize(15)
            .enabled(!this.scanning)
            .onClick((): void => {
              this.doCapture();
            })
          Button('相册选图')
            .layoutWeight(1).height(44).borderRadius(22)
            .backgroundColor($r('app.color.accent_soft'))
            .fontColor($r('app.color.accent'))
            .fontSize(15)
            .enabled(!this.scanning)
            .onClick((): void => {
              this.doScan();
            })
          Button('示例')
            .height(44).borderRadius(22)
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.text_secondary'))
            .fontSize(14)
            .enabled(!this.scanning)
            .onClick((): void => {
              this.rawText = SAMPLE_MENU;
            })
        }
        .width('100%')

        TextArea({
          placeholder: '识别结果（可手动修正）：含菜名、食材用量与做法步骤',
          text: this.rawText
        })
          .width('100%')
          .height(200)
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .onChange((v: string): void => {
            this.rawText = v;
          })

        // 解析预览（识别/输入后即时反馈）
        if (this.preview() !== null) {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(16).fontColor([$r('app.color.accent')])
              Text((this.preview() as Recipe).name).fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Blank()
            }
            .width('100%')
            Row({ space: 14 }) {
              Text(`${(this.preview() as Recipe).ingredients.length} 种食材`)
                .fontSize(12).fontColor($r('app.color.text_secondary'))
              Text(`${(this.preview() as Recipe).steps.length} 步`)
                .fontSize(12).fontColor($r('app.color.text_secondary'))
              Text(`约 ${(this.preview() as Recipe).nutrition.kcal} kcal/份`)
                .fontSize(12).fontColor($r('app.color.text_secondary'))
              Blank()
            }
            .width('100%')
            if ((this.preview() as Recipe).ingredients.length === 0 || (this.preview() as Recipe).steps.length === 0) {
              Text('未识别出食材或步骤，可修正上方文本（保留「食材：」「做法：」分段）后重试')
                .fontSize(11).fontColor($r('app.color.tag_orange')).width('100%')
            }
          }
          .width('100%').padding(14).borderRadius(14)
          .backgroundColor($r('app.color.accent_soft'))
          .alignItems(HorizontalAlign.Start)
        }

        Button('识别并加入菜单库')
          .width('100%')
          .height(46).borderRadius(23)
          .backgroundColor($r('app.color.accent'))
          .fontColor(Color.White)
          .onClick((): void => {
            this.save();
          })

        // 手动创建入口
        Row({ space: 6 }) {
          Text('识别不准？').fontSize(13).fontColor($r('app.color.text_tertiary'))
          Text('手动创建菜谱')
            .fontSize(13).fontColor($r('app.color.accent'))
            .onClick((): void => {
              router.pushUrl({ url: 'pages/RecipeManual' });
            })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding({ top: 4 })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    }
  }

  /** 拍菜单：系统相机（零权限）→ 落盘校验 → OCR */
  private async doCapture(): Promise<void> {
    this.scanning = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const path: string = await ReceiptParser.captureReceipt(ctx);
      if (path.length === 0) {
        promptAction.showToast({ message: '未拍摄照片' });
      } else {
        const text: string = await ReceiptParser.recognizeFromPath(path);
        this.rawText = text;
      }
    } catch (e) {
      const msg: string = (e as Error).message ?? '';
      promptAction.showToast({ message: msg.length > 0 ? `识别失败：${msg}` : '识别失败，请重试或手动输入' });
    }
    this.scanning = false;
  }

  /** 相册选图 → OCR */
  private async doScan(): Promise<void> {
    this.scanning = true;
    try {
      const text: string = await ReceiptParser.scanReceipt();
      if (text.length === 0) {
        promptAction.showToast({ message: '未选择图片' });
      } else {
        this.rawText = text;
      }
    } catch (e) {
      const msg: string = (e as Error).message ?? '';
      promptAction.showToast({ message: msg.length > 0 ? `识别失败：${msg}` : '识别失败，请重试或手动输入' });
    }
    this.scanning = false;
  }

  private save(): void {
    if (this.rawText.trim().length < 10) {
      promptAction.showToast({ message: '请先识别或输入菜谱内容' });
      return;
    }
    const recipe: Recipe = RecipeParser.parse(this.rawText, '图片识别菜谱');
    if (recipe.ingredients.length === 0 && recipe.steps.length === 0) {
      promptAction.showToast({ message: '未能识别出食材或步骤，请修正文本后重试' });
      return;
    }
    recipe.source = '图片识别';
    DataStore.saveRecipe(recipe);
    promptAction.showToast({
      message: `已入库：${recipe.name}（${recipe.ingredients.length}种食材 / ${recipe.steps.length}步）`
    });
    router.back();
  }
}

const SAMPLE_MENU: string = `青椒肉丝

食材：
青椒 2个
里脊肉 200克
蒜 2瓣
生抽 1勺
盐 3克

做法：
1. 里脊肉切丝，加生抽淀粉抓匀腌10分钟。
2. 青椒去籽切丝，蒜切片。
3. 热油下滑肉丝炒至变色盛出。
4. 留底油爆香蒜片，下青椒丝炒断生。
5. 倒回肉丝，加盐翻炒均匀出锅。`;
