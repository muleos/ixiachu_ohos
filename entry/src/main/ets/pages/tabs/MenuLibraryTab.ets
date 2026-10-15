/** 功能一：菜单库 —— 导入文字菜谱 / 列表 / 详情入口 */
import { router } from '@kit.ArkUI';
import { Recipe } from '../../model/Models';
import { DataStore } from '../../service/DataStore';
import { topAvoid } from '../../utils/Theme';

@Component
export struct MenuLibraryTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('dataRev') @Watch('reload') dataRev: number = 0;
  @State keyword: string = '';
  @State category: string = '全部';
  /** 菜谱列表用 @State 承载，dataRev 变化（种入/导入）后自动刷新 */
  @State allRecipes: Recipe[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.allRecipes = DataStore.getRecipes().slice();
  }

  /** 分类筛选：全部 + 菜谱库中实际出现的分类 */
  private categories(): string[] {
    const set: string[] = ['全部'];
    for (const r of this.allRecipes) {
      if (r.category.length > 0 && set.indexOf(r.category) < 0) {
        set.push(r.category);
      }
    }
    return set;
  }

  build() {
    Column() {
      // 操作行：搜索 + 导入入口（随状态栏留白，与酷安分段控件同款布局）
      Row() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(16)
            .fontColor([$r('app.color.text_tertiary')])
          TextInput({ placeholder: '搜索菜名或标签', text: this.keyword })
            .backgroundColor(Color.Transparent)
            .border({ width: 0 })
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
            .onChange((v: string): void => {
              this.keyword = v;
            })
        }
        .layoutWeight(1)
        .height(40)
        .padding({ left: 14, right: 14 })
        .borderRadius(20)
        .backgroundColor($r('app.color.card_background'))

        Button() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.picture'))
              .fontSize(18)
              .fontColor([$r('app.color.accent')])
            Text('识别').fontSize(14).fontColor($r('app.color.accent'))
          }
        }
        .backgroundColor($r('app.color.accent_soft'))
        .height(40)
        .borderRadius(20)
        .margin({ left: 10 })
        .onClick((): void => {
          router.pushUrl({ url: 'pages/MenuScan' });
        })

        Button() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.plus_circle'))
              .fontSize(18)
              .fontColor([$r('app.color.accent')])
            Text('导入').fontSize(14).fontColor($r('app.color.accent'))
          }
        }
        .backgroundColor($r('app.color.accent_soft'))
        .height(40)
        .borderRadius(20)
        .margin({ left: 10 })
        .onClick((): void => {
          router.pushUrl({ url: 'pages/RecipeImport' });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: topAvoid(this.statusBarHeight) + 8, bottom: 12 })

      // 分类筛选 chips
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.categories(), (c: string): void => {
            Text(c)
              .fontSize(13)
              .fontColor(this.category === c ? Color.White : $r('app.color.text_secondary'))
              .backgroundColor(this.category === c ? $r('app.color.accent') : $r('app.color.card_background'))
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .borderRadius(16)
              .onClick((): void => {
                this.category = c;
              })
          }, (c: string): string => c)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ bottom: 10 })

      List({ scroller: this.pageScroller, space: 12 }) {
        ListItem() {
          Text(`共 ${this.filtered().length} 道菜`)
            .fontSize(12).fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .padding({ left: 4, bottom: 2 })
        }
        ForEach(this.filtered(), (r: Recipe): void => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(r.name)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                Blank()
                if (r.grade.length > 0) {
                  Row({ space: 2 }) {
                    SymbolGlyph($r('sys.symbol.star'))
                      .fontSize(12)
                      .fontColor([$r('app.color.tag_orange')])
                    Text(r.grade).fontSize(12).fontColor($r('app.color.tag_orange')).fontWeight(FontWeight.Medium)
                  }
                  .margin({ right: 6 })
                }
                ForEach(r.tags, (t: string): void => {
                  Text(t)
                    .fontSize(11)
                    .fontColor($r('app.color.accent'))
                    .backgroundColor($r('app.color.accent_soft'))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .borderRadius(8)
                    .margin({ left: 4 })
                }, (t: string): string => t)
              }
              .width('100%')
              Row({ space: 14 }) {
                Text(`${r.ingredients.length} 种食材`).fontSize(12).fontColor($r('app.color.text_secondary'))
                Text(`${r.steps.length} 步`).fontSize(12).fontColor($r('app.color.text_secondary'))
                Text(`约 ${r.nutrition.kcal} kcal/份`).fontSize(12).fontColor($r('app.color.text_secondary'))
                Blank()
                if (r.category.length > 0) {
                  Text(r.category).fontSize(11).fontColor($r('app.color.text_tertiary'))
                }
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .onClick((): void => {
              AppStorage.setOrCreate<string>('currentRecipeId', r.id);
              router.pushUrl({ url: 'pages/RecipeDetail' });
            })
          }
        }, (r: Recipe): string => `${r.id}_${this.dataRev}`)

        if (this.filtered().length === 0) {
          ListItem() {
            Column({ space: 10 }) {
              Text('还没有菜谱').fontSize(16).fontColor($r('app.color.text_secondary'))
              Text('点击右上角「导入菜谱」，粘贴文字版菜谱即可自动识别').fontSize(13).fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            .padding({ top: 60, bottom: 60 })
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 120 })
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  private filtered(): Recipe[] {
    let list: Recipe[] = [];
    for (const r of this.allRecipes) {
      if (this.keyword.length > 0 && r.name.indexOf(this.keyword) < 0 && r.tags.join(',').indexOf(this.keyword) < 0) {
        continue;
      }
      if (this.category !== '全部' && r.category !== this.category) {
        continue;
      }
      list.push(r);
    }
    return list;
  }
}
