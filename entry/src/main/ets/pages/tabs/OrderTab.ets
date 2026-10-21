/**
 * 功能二：点菜（v1.12.0 合并版）——
 * 灵感区（盲盒抽卡 / 二十四节气时令）+ 点菜区（随机点菜与按需求推荐合并为
 * 一张卡：人数/热量上限/餐标预算/时令优先/优先消耗库存，填了条件走推荐、
 * 全空走随机，功能全保留）+ 今日菜单结果卡。
 */
import { router, promptAction } from '@kit.ArkUI';
import { DailyMenu, FreshLevel, ShoppingItem, StockItem } from '../../model/Models';
import { DataStore } from '../../service/DataStore';
import { MenuPlanner } from '../../service/MenuPlanner';
import { Freshness } from '../../service/Freshness';
import { InspirationData } from '../../service/InspirationData';
import { topAvoid } from '../../utils/Theme';
import { WidgetSync } from '../../service/WidgetSync';

@Component
export struct OrderTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('dataRev') dataRev: number = 0;
  @State people: number = 3;
  @State maxKcal: number = 0;
  @State budget: number = 0;
  @State seasonal: boolean = false;
  @State useStock: boolean = true;
  @State menu: DailyMenu | null = null;

  aboutToAppear(): void {
    // 有临期食材时自动开启「优先消耗库存」
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

  /** 生成菜单：填了任一推荐条件走按需求推荐，否则纯随机 */
  private generate(): void {
    const hasRequirement: boolean = this.maxKcal > 0 || this.budget > 0 || this.seasonal;
    if (hasRequirement) {
      this.menu = MenuPlanner.recommend(this.people, this.maxKcal, this.budget, this.seasonal, this.useStock);
    } else {
      this.menu = MenuPlanner.randomMenu(this.people);
    }
    DataStore.addMenu(this.menu);
  }

  build() {
    Scroll(this.pageScroller) {
      Column({ space: 14 }) {
        // ① 灵感盲盒 · 今天吃什么
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Row({ space: 6 }) {
              Text('✦ 灵感盲盒').fontSize(11).fontColor(Color.White)
                .backgroundColor($r('app.color.accent'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10)
              Text('摇一摇抽卡').fontSize(11).fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            Text('今天吃什么').fontSize(19).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('纠结这一餐？抽一张私房风味签')
              .fontSize(12).fontColor($r('app.color.text_secondary')).width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.gift'))
              .fontSize(24).fontColor([Color.White])
            Text('盲盒').fontSize(10).fontColor(Color.White)
          }
          .width(78)
          .height(92)
          .justifyContent(FlexAlign.Center)
          .borderRadius(14)
          .linearGradient({
            angle: 160,
            colors: [['#F08A3C', 0], ['#ED6D3D', 1]]
          })
          .shadow({ radius: 12, color: '#33ED6D3D', offsetY: 4 })
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_background'))
        .onClick((): void => {
          router.pushUrl({ url: 'pages/InspirationMystery' });
        })

        // ② 二十四节气 · 时令推荐
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Row({ space: 6 }) {
              Text('❋ 二十四节气').fontSize(11).fontColor($r('app.color.accent'))
                .backgroundColor($r('app.color.accent_soft'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10)
              Text(`${InspirationData.seasonOf(new Date()).term} · 当令`).fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            Text('时令推荐').fontSize(19).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text(InspirationData.seasonOf(new Date()).desc)
              .fontSize(12).fontColor($r('app.color.text_secondary'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(`探索 ${InspirationData.seasonOf(new Date()).matchCount()} 道好味 ›`)
              .fontSize(12).fontColor($r('app.color.accent'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column({ space: 4 }) {
            Text(InspirationData.seasonOf(new Date()).key).fontSize(26).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent'))
            Text(`${InspirationData.seasonOf(new Date()).term} · ${InspirationData.seasonOf(new Date()).sub}`)
              .fontSize(9).fontColor($r('app.color.text_secondary'))
          }
          .width(78)
          .height(92)
          .justifyContent(FlexAlign.Center)
          .borderRadius(14)
          .backgroundColor($r('app.color.accent_soft'))
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_background'))
        .onClick((): void => {
          router.pushUrl({ url: 'pages/InspirationSeason' });
        })

        // ③ 开始点菜（随机 + 按需求 合并卡）
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.shuffle')).fontSize(16).fontColor([$r('app.color.accent')])
            Text('开始点菜').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            Blank()
            Text('填条件=按需求 · 全空=随机')
              .fontSize(10).fontColor($r('app.color.text_tertiary'))
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

          Row({ space: 12 }) {
            Text('热量上限').fontSize(14).fontColor($r('app.color.text_secondary'))
            TextInput({ placeholder: 'kcal/人（选填）' })
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
            TextInput({ placeholder: '元（选填）' })
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

          Button('生成菜单')
            .width('100%').height(44).borderRadius(22)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .onClick((): void => {
              this.generate();
            })
        }
        .width('100%').padding(16).borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // ④ 点菜结果
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

            // 营养面板（每人每餐估算；两行布局防长文案出框）
            Column({ space: 4 }) {
              Row() {
                Text('营养估算（每人每餐）')
                  .fontSize(12).fontColor($r('app.color.text_tertiary'))
                Blank()
              }
              .width('100%')
              Text(`${(this.menu as DailyMenu).totalKcal} kcal · 蛋白 ${(this.menu as DailyMenu).protein}g · 脂肪 ${(this.menu as DailyMenu).fat}g · 碳水 ${(this.menu as DailyMenu).carbs}g`)
                .fontSize(11).fontColor($r('app.color.text_secondary'))
                .width('100%')
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
      .padding({ left: 16, right: 16, top: topAvoid(this.statusBarHeight) + 8, bottom: 92 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }
}
