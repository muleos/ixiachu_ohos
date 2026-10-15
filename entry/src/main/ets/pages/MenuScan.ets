/**
 * 菜单图片识别：拍菜单 / 菜谱照片 → 系统文字识别（Core Vision Kit）
 * → 复用菜谱文本解析（菜名 / 食材用量 / 步骤 / 营养热量）→ 入库菜单库。
 */
import { router, promptAction } from '@kit.ArkUI';
import { Recipe } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { RecipeParser } from '../service/RecipeParser';
import { ReceiptParser } from '../service/ReceiptParser';
import { queryStatusBarHeight } from '../utils/Theme';

@Entry
@Component
struct MenuScan {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @State queriedBar: number = 0;
  @State rawText: string = '';
  @State scanning: boolean = false;

  aboutToAppear(): void {
    queryStatusBarHeight(getContext(this)).then((h: number): void => {
      if (h > 0) {
        this.queriedBar = h;
      }
    });
  }

  private topBar(): number {
    return Math.max(Math.max(this.statusBarHeight, this.queriedBar), 36);
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
          .onClick((): void => {
            router.back();
          })
        Text('菜单图片识别')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .padding({ left: 12, right: 20, top: this.topBar() })

      Row({ space: 12 }) {
        Button(this.scanning ? '识别中…' : '拍菜单 / 选图识别')
          .layoutWeight(2).height(44).borderRadius(22)
          .backgroundColor($r('app.color.accent'))
          .fontColor(Color.White)
          .enabled(!this.scanning)
          .onClick((): void => {
            this.doScan();
          })
        Button('示例')
          .layoutWeight(1).height(44).borderRadius(22)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick((): void => {
            this.rawText = SAMPLE_MENU;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })

      TextArea({
        placeholder: '识别结果（可手动修正）：含菜名、食材用量与做法步骤',
        text: this.rawText
      })
        .width('100%')
        .height(200)
        .margin({ left: 20, right: 20, top: 12 })
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .onChange((v: string): void => {
          this.rawText = v;
        })

      Blank()

      Button('识别并加入菜单库')
        .width('calc(100% - 40vp)')
        .height(46).borderRadius(23).margin({ bottom: 20 })
        .backgroundColor($r('app.color.accent'))
        .fontColor(Color.White)
        .onClick((): void => {
          this.save();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

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
