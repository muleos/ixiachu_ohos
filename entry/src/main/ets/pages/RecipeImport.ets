/**
 * 导入菜谱：
 * ① 手动创建（表单式，参照系统菜谱 App 体验）；
 * ② 粘贴文字版菜谱 → 自动识别食材/做法/营养热量；
 * ③ 下厨房在线导入 —— 接口结构对齐 ruter/xiachufang-api（自部署服务地址可配置）。
 * v1.10.0：顶栏换官方 FrostPage 沉浸光感；新增手动创建入口。
 */
import { router, promptAction } from '@kit.ArkUI';
import { RecipeParser } from '../service/RecipeParser';
import { DataStore } from '../service/DataStore';
import { XiachufangApi } from '../service/XiachufangApi';
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

const API_BASE_KEY: string = 'xiachufang_api_base';
const DEFAULT_API_BASE: string = 'http://127.0.0.1:5000';

@Entry
@Component
struct RecipeImport {
  private scroller: Scroller = new Scroller();
  @State text: string = '';
  @State apiBase: string = '';
  @State recipeInput: string = '';
  @State importing: boolean = false;

  aboutToAppear(): void {
    const saved: string = DataStore.getSetting(API_BASE_KEY);
    this.apiBase = saved.length > 0 ? saved : DEFAULT_API_BASE;
  }

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

          // ① 文字粘贴识别
          Column({ space: 8 }) {
            Text('粘贴文字版菜谱').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              .width('100%')
            TextArea({
              placeholder: '支持「食材/用料」与「做法/步骤」分段，\n自动识别菜名、食材用量、营养价值与热量估算。',
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
                  if (this.text.trim().length < 10) {
                    promptAction.showToast({ message: '请先粘贴菜谱文本' });
                    return;
                  }
                  const recipe = RecipeParser.parse(this.text, '未命名菜谱');
                  DataStore.saveRecipe(recipe);
                  promptAction.showToast({ message: `已识别：${recipe.name}（${recipe.ingredients.length}种食材 / ${recipe.steps.length}步 / 约${recipe.nutrition.kcal}kcal每份）` });
                  router.back();
                })
            }
            .width('100%')
          }
          .width('100%').padding(16).borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .alignItems(HorizontalAlign.Start)

          // ② 在线导入（下厨房）
          Column({ space: 10 }) {
            Text('下厨房在线导入').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            TextInput({ placeholder: '服务地址（自部署 xiachufang-api）', text: this.apiBase })
              .height(38).fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((v: string): void => {
                this.apiBase = v;
                DataStore.setSetting(API_BASE_KEY, v);
              })
            TextInput({ placeholder: '粘贴菜谱链接或 ID，如 https://www.xiachufang.com/recipe/101772749/', text: this.recipeInput })
              .height(38).fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((v: string): void => {
                this.recipeInput = v;
              })
            Button(this.importing ? '拉取中…' : '从下厨房导入')
              .width('100%').height(40).borderRadius(20)
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .enabled(!this.importing)
              .onClick((): void => {
                this.doOnlineImport();
              })
            Text('需自行部署 ruter/xiachufang-api 服务并填入地址；解析其 /recipe/{id}/ 接口')
              .fontSize(11).fontColor($r('app.color.text_tertiary'))
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

  private async doOnlineImport(): Promise<void> {
    const id: string = XiachufangApi.extractId(this.recipeInput);
    if (id.length === 0) {
      promptAction.showToast({ message: '请粘贴有效的下厨房菜谱链接或 ID' });
      return;
    }
    if (this.apiBase.trim().length === 0) {
      promptAction.showToast({ message: '请先填写 xiachufang-api 服务地址' });
      return;
    }
    this.importing = true;
    try {
      const recipe = await XiachufangApi.fetchRecipe(this.apiBase.trim(), id);
      DataStore.saveRecipe(recipe);
      promptAction.showToast({ message: `已导入：${recipe.name}（${recipe.ingredients.length}种食材 / ${recipe.steps.length}步）` });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: `导入失败：${(e as Error).message}，请检查服务地址与网络` });
    }
    this.importing = false;
  }
}
