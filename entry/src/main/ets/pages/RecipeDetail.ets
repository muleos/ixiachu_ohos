/** 菜谱详情：食材 / 做法 / 营养价值与热量估算（v1.10.0 官方沉浸光感顶栏 + 封面图） */
import { router } from '@kit.ArkUI';
import { Recipe, RecipeIngredient, RecipeStep } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { promptAction } from '@kit.ArkUI';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct RecipeDetail {
  private scroller: Scroller = new Scroller();
  @StorageProp('dataRev') dataRev: number = 0;

  build() {
    Stack() {
    FrostPage({
      title: '菜谱详情',
      scroller: this.scroller,
      rightIcon: $r('sys.symbol.trash'),
      rightIconColor: $r('app.color.tag_red'),
      onRight: (): void => {
        promptAction.showDialog({
          title: '删除菜谱',
          message: `确定删除「${(this.recipe() as Recipe).name}」？删除后不可恢复。`,
          buttons: [
            { text: '取消', color: '#666666' },
            { text: '删除', color: '#F8284C' }
          ]
        }).then((result: promptAction.ShowDialogSuccessResponse): void => {
          if (result.index === 1) {
            const id: string = AppStorage.get<string>('currentRecipeId') ?? '';
            DataStore.deleteRecipe(id);
            router.back();
          }
        });
      }
    }) {
      Column({ space: 16 }) {
        // 封面图（手动创建选填；旧数据 cover 可能缺失，兜底空串）
        if (((this.recipe() as Recipe).cover ?? '').length > 0) {
          Image(`file://${(this.recipe() as Recipe).cover}`)
            .width('100%')
            .height(200)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
            .backgroundColor($r('app.color.card_background'))
        }

        // 配图（网页导入保存的相关图片）
        if (this.imgs().length > 0) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.imgs(), (p: string): void => {
                Image(`file://${p}`)
                  .width(128)
                  .height(96)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)
                  .backgroundColor($r('app.color.card_background'))
              }, (p: string): string => p)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }

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

        // 小贴士 / 风味随笔
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
      .padding({ left: 20, right: 20 })
    }
    }
  }

  private recipe(): Recipe {
    const id: string = AppStorage.get<string>('currentRecipeId') ?? '';
    const r: Recipe | null = DataStore.getRecipe(id);
    return r !== null ? r : new Recipe();
  }

  /** 配图列表（存量数据兜底） */
  private imgs(): string[] {
    const list: string[] | undefined = (this.recipe() as Recipe).images;
    return list === undefined || list === null ? [] : list;
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
