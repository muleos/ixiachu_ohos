/** 功能二：点菜 —— 搜索 / 人数随机 / 需求推荐 / 一键生成采购清单 */
import { promptAction } from '@kit.ArkUI';
import { DailyMenu, FreshLevel, Recipe, ShoppingItem, StockItem } from '../../model/Models';
import { DataStore } from '../../service/DataStore';
import { MenuPlanner } from '../../service/MenuPlanner';
import { Freshness } from '../../service/Freshness';
import { topAvoid } from '../../utils/Theme';
import { WidgetSync } from '../../service/WidgetSync';

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

  aboutToAppear(): void {
    // 有临期食材时自动开启「优先消耗库存」（默认本就开启，这里兜底显式置位）
    if (this.urgentCount() > 0) {
      this.useStock = true;
    }
  }

  /** 临期食材数（SOON/CHECK 级，月份代理口径） */
  private urgentCount(): number {
    const now: Date = new Date();
    return DataStore.getStock().filter((s: StockItem): boolean =>
      Freshness.level(Freshness.decayRatioSync(s, now, Freshness.monthFactor(now))) >= FreshLevel.SOON).length;
  }

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
              Text(this.urgentCount() > 0
                ? `优先消耗库存（${this.urgentCount()} 项临期，已自动开启）`
                : '优先消耗库存')
                .fontSize(13)
                .fontColor(this.urgentCount() > 0 ? $r('app.color.tag_orange') : $r('app.color.text_secondary'))
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

            // 结构审查提示（荤素汤配比/热量超限）
            if ((this.menu as DailyMenu).review.length > 0) {
              Column({ space: 4 }) {
                ForEach((this.menu as DailyMenu).review, (t: string): void => {
                  Text(`💡 ${t}`).fontSize(12).fontColor($r('app.color.tag_orange')).width('100%')
                }, (t: string): string => t)
              }
              .width('100%')
              .padding({ top: 6, bottom: 6, left: 10, right: 10 })
              .borderRadius(10)
              .backgroundColor($r('app.color.page_background'))
            }

            // 营养面板（每人每餐估算）
            Row() {
              Text('营养估算（每人每餐）')
                .fontSize(12).fontColor($r('app.color.text_tertiary'))
              Blank()
              Text(`${(this.menu as DailyMenu).totalKcal} kcal · 蛋白 ${(this.menu as DailyMenu).protein}g · 脂肪 ${(this.menu as DailyMenu).fat}g · 碳水 ${(this.menu as DailyMenu).carbs}g`)
                .fontSize(11).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ top: 6, bottom: 6, left: 10, right: 10 })
            .borderRadius(10)
            .backgroundColor($r('app.color.page_background'))

            Button((this.menu as DailyMenu).confirmed ? '已确认开做 · 库存已按菜谱扣减' : '确认开做并生成采购清单')
              .width('100%').height(40).borderRadius(20)
              .backgroundColor((this.menu as DailyMenu).confirmed ? $r('app.color.page_background') : $r('app.color.accent_soft'))
              .fontColor((this.menu as DailyMenu).confirmed ? $r('app.color.text_tertiary') : $r('app.color.accent'))
              .enabled(!(this.menu as DailyMenu).confirmed)
              .onClick((): void => {
                try {
                  const menu: DailyMenu = this.menu as DailyMenu;
                  const list: ShoppingItem[] = MenuPlanner.buildShoppingList(menu);
                  DataStore.setShopping(list);
                  const deducted: number = DataStore.consumeStock(menu);
                  WidgetSync.updateAll();
                  DataStore.confirmMenu(menu.id);
                  menu.confirmed = true;
                  promptAction.showToast({
                    message: `采购清单已生成（${list.length} 项），已按菜谱扣减库存 ${deducted} 处，请到「采购」页查看`
                  });
                } catch (e) {
                  promptAction.showToast({ message: `生成失败：${(e as Error).message}` });
                }
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
      .padding({ left: 16, right: 16, top: topAvoid(this.statusBarHeight) + 8, bottom: 120 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }
}
