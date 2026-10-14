/** 功能二：点菜 —— 搜索 / 人数随机 / 需求推荐 / 一键生成采购清单 */
import { promptAction } from '@kit.ArkUI';
import { DailyMenu, Recipe } from '../../model/Models';
import { DataStore } from '../../service/DataStore';
import { MenuPlanner } from '../../service/MenuPlanner';
import { NAV_TITLE_HEIGHT } from '../../utils/Theme';

@Component
export struct OrderTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('dataRev') dataRev: number = 0;
  @State keyword: string = '';
  @State people: number = 3;
  @State maxKcal: number = 0;
  @State budget: number = 0;
  @State seasonal: boolean = false;
  @State useStock: boolean = true;
  @State menu: DailyMenu | null = null;

  build() {
    Scroll(this.pageScroller) {
      Column({ space: 14 }) {
        // 搜索菜单库
        Row() {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(16).fontColor([$r('app.color.text_tertiary')])
          TextInput({ placeholder: '搜索菜单库中的菜名', text: this.keyword })
            .backgroundColor(Color.Transparent).border({ width: 0 })
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
            .onChange((v: string): void => {
              this.keyword = v;
            })
        }
        .width('100%').height(40).padding({ left: 14, right: 14 })
        .borderRadius(20).backgroundColor($r('app.color.card_background'))

        // 搜索结果
        if (this.keyword.length > 0) {
          ForEach(MenuPlanner.search(this.keyword), (r: Recipe): void => {
            Row() {
              Text(r.name).fontSize(15).fontColor($r('app.color.text_primary'))
              Blank()
              Text(`约 ${r.nutrition.kcal} kcal`).fontSize(12).fontColor($r('app.color.text_tertiary'))
            }
            .width('100%').padding(14).borderRadius(12)
            .backgroundColor($r('app.color.card_background'))
          }, (r: Recipe): string => r.id)
        }

        // 随机点菜
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.shuffle')).fontSize(16).fontColor([$r('app.color.accent')])
            Text('随机点菜').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          Row({ space: 12 }) {
            Text('用餐人数').fontSize(14).fontColor($r('app.color.text_secondary'))
            Blank()
            Counter() {
              Text(`${this.people}`)
            }
            .onInc((): void => {
              this.people = Math.min(20, this.people + 1);
            })
            .onDec((): void => {
              this.people = Math.max(1, this.people - 1);
            })
          }
          .width('100%')
          Button('随机生成菜单')
            .width('100%').height(44).borderRadius(22)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .onClick((): void => {
              this.menu = MenuPlanner.randomMenu(this.people);
              DataStore.addMenu(this.menu);
            })
        }
        .width('100%').padding(16).borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // 需求推荐
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.dart_target')).fontSize(16).fontColor([$r('app.color.accent')])
            Text('按需求推荐').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          Row({ space: 12 }) {
            Text('热量上限').fontSize(14).fontColor($r('app.color.text_secondary'))
            TextInput({ placeholder: 'kcal/人（可空）' })
              .type(InputType.NUMBER_DECIMAL)
              .height(36).fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((v: string): void => {
                this.maxKcal = parseFloat(v) || 0;
              })
          }
          .width('100%')
          Row({ space: 12 }) {
            Text('餐标预算').fontSize(14).fontColor($r('app.color.text_secondary'))
            TextInput({ placeholder: '元（可空）' })
              .type(InputType.NUMBER_DECIMAL)
              .height(36).fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((v: string): void => {
                this.budget = parseFloat(v) || 0;
              })
          }
          .width('100%')
          Row({ space: 24 }) {
            Row({ space: 6 }) {
              Toggle({ type: ToggleType.Checkbox, isOn: this.seasonal })
                .onChange((on: boolean): void => {
                  this.seasonal = on;
                })
                .selectedColor($r('app.color.accent'))
              Text('时令优先').fontSize(13).fontColor($r('app.color.text_secondary'))
            }
            Row({ space: 6 }) {
              Toggle({ type: ToggleType.Checkbox, isOn: this.useStock })
                .onChange((on: boolean): void => {
                  this.useStock = on;
                })
                .selectedColor($r('app.color.accent'))
              Text('优先消耗库存').fontSize(13).fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          Button('生成推荐菜单')
            .width('100%').height(44).borderRadius(22)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .onClick((): void => {
              this.menu = MenuPlanner.recommend(this.people, this.maxKcal, this.budget, this.seasonal, this.useStock);
              DataStore.addMenu(this.menu);
            })
        }
        .width('100%').padding(16).borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // 点菜结果
        if (this.menu !== null && (this.menu as DailyMenu).recipeNames.length > 0) {
          Column({ space: 10 }) {
            Row() {
              Text('今日菜单').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              Blank()
              Text(`${(this.menu as DailyMenu).people}人 · 约${(this.menu as DailyMenu).totalKcal}kcal/人 · 预算≈¥${(this.menu as DailyMenu).budget}`)
                .fontSize(12).fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            ForEach((this.menu as DailyMenu).recipeNames, (n: string, i: number): void => {
              Row({ space: 10 }) {
                Text(`${i + 1}`).fontSize(13).fontColor($r('app.color.accent')).fontWeight(FontWeight.Medium)
                Text(n).fontSize(15).fontColor($r('app.color.text_primary'))
              }
              .width('100%').padding({ top: 6, bottom: 6 })
            }, (n: string): string => n)
            Button('生成采购清单')
              .width('100%').height(40).borderRadius(20)
              .backgroundColor($r('app.color.accent_soft'))
              .fontColor($r('app.color.accent'))
              .onClick((): void => {
                const list = MenuPlanner.buildShoppingList(this.menu as DailyMenu);
                DataStore.setShopping(list);
                DataStore.consumeStock((this.menu as DailyMenu).recipeIds);
                promptAction.showToast({ message: '采购清单已生成，请到「采购」页查看' });
              })
          }
          .width('100%').padding(16).borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
        } else if (this.menu !== null) {
          Text('菜单库为空，请先到「菜单库」导入菜谱')
            .fontSize(13).fontColor($r('app.color.text_tertiary')).padding(16)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + NAV_TITLE_HEIGHT + 8, bottom: 120 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }
}
