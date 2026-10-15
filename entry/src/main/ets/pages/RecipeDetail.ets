/** 菜谱详情：食材 / 做法 / 营养价值与热量估算 */
import { router } from '@kit.ArkUI';
import { Recipe, RecipeIngredient, RecipeStep } from '../model/Models';
import { DataStore } from '../service/DataStore';

@Entry
@Component
struct RecipeDetail {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('dataRev') dataRev: number = 0;

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
          .onClick((): void => {
            router.back();
          })
        Text('菜谱详情')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
        Blank()
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(18)
          .fontColor([$r('app.color.tag_red')])
          .onClick((): void => {
            const id: string = AppStorage.get<string>('currentRecipeId') ?? '';
            DataStore.deleteRecipe(id);
            router.back();
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 20, top: Math.max(this.statusBarHeight, 36) })

      Scroll() {
        Column({ space: 16 }) {
          Text((this.recipe() as Recipe).name)
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            .width('100%')

          Row({ space: 8 }) {
            ForEach((this.recipe() as Recipe).tags, (t: string): void => {
              Text(t).fontSize(11).fontColor($r('app.color.accent'))
                .backgroundColor($r('app.color.accent_soft'))
                .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(8)
            }, (t: string): string => t)
            if ((this.recipe() as Recipe).category.length > 0) {
              Text((this.recipe() as Recipe).category).fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(8)
                .backgroundColor($r('app.color.page_background'))
            }
            if ((this.recipe() as Recipe).grade.length > 0) {
              Row({ space: 2 }) {
                SymbolGlyph($r('sys.symbol.star')).fontSize(12).fontColor([$r('app.color.tag_orange')])
                Text((this.recipe() as Recipe).grade).fontSize(12)
                  .fontColor($r('app.color.tag_orange')).fontWeight(FontWeight.Medium)
              }
            }
            Blank()
            Text(`${(this.recipe() as Recipe).servings}人份 · ${((this.recipe() as Recipe).source)}`)
              .fontSize(11).fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')

          // 营养价值与热量估算
          Row({ space: 10 }) {
            this.NutriCell('热量', `${(this.recipe() as Recipe).nutrition.kcal}`, 'kcal')
            this.NutriCell('蛋白质', `${(this.recipe() as Recipe).nutrition.protein}`, 'g')
            this.NutriCell('脂肪', `${(this.recipe() as Recipe).nutrition.fat}`, 'g')
            this.NutriCell('碳水', `${(this.recipe() as Recipe).nutrition.carbs}`, 'g')
          }
          .width('100%')

          this.SectionTitle('食材')
          ForEach((this.recipe() as Recipe).ingredients, (ing: RecipeIngredient): void => {
            Row() {
              Text(ing.name).fontSize(15).fontColor($r('app.color.text_primary'))
              Blank()
              Text(ing.amount > 0
                ? (ing.unit === '克' || ing.unit === 'g' || ing.unit === '毫升' || ing.unit === 'ml'
                  ? `${ing.amount >= 1000 ? (ing.amount / 1000).toFixed(1) + 'kg' : ing.amount + ing.unit}`
                  : `${ing.amount}${ing.unit}`)
                : (ing.raw.length > 0 ? ing.raw : '适量'))
                .fontSize(13).fontColor($r('app.color.text_secondary'))
            }
            .width('100%').padding({ top: 8, bottom: 8 })
            .borderWidth({ bottom: 0.5 })
            .borderColor($r('app.color.divider'))
          }, (ing: RecipeIngredient): string => ing.name)

          this.SectionTitle('做法')
          ForEach((this.recipe() as Recipe).steps, (s: RecipeStep): void => {
            Row({ space: 12 }) {
              Text(`${s.index}`)
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .width(24).height(24).textAlign(TextAlign.Center)
                .borderRadius(12).backgroundColor($r('app.color.accent'))
              Text(s.text).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
            }
            .alignItems(VerticalAlign.Top)
            .width('100%').padding({ top: 8, bottom: 8 })
          }, (s: RecipeStep): string => `${s.index}`)

          // 小贴士（下厨房数据）
          if ((this.recipe() as Recipe).tip.length > 0) {
            Column({ space: 6 }) {
              Text('小贴士').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.accent'))
              Text((this.recipe() as Recipe).tip).fontSize(14).fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(14)
            .borderRadius(12)
            .backgroundColor($r('app.color.accent_soft'))
          }
        }
        .width('100%')
        .padding(20)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  private recipe(): Recipe {
    const id: string = AppStorage.get<string>('currentRecipeId') ?? '';
    const r: Recipe | null = DataStore.getRecipe(id);
    return r !== null ? r : new Recipe();
  }

  @Builder
  SectionTitle(title: string) {
    Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary')).width('100%')
  }

  @Builder
  NutriCell(label: string, value: string, unit: string) {
    Column({ space: 2 }) {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
      Text(`${label}(${unit})`).fontSize(10).fontColor($r('app.color.text_tertiary'))
    }
    .padding({ top: 10, bottom: 10 })
    .layoutWeight(1)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
  }
}
