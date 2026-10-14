/** 功能三：采购清单 —— 按点菜汇总 + 当日基础菜价参考区间 */
import { DataStore } from '../../service/DataStore';
import { ShoppingItem } from '../../model/Models';
import { NAV_TITLE_HEIGHT } from '../../utils/Theme';

@Component
export struct ShoppingTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  /** 采购清单专属广播键：@StorageLink 强绑定，生成/勾选/清除都会立即触发 reload */
  @StorageLink('shoppingRev') @Watch('reload') shoppingRev: number = 0;
  /** 列表用 @State 承载：非状态方法调用不会触发条件分支重渲染 */
  @State items: ShoppingItem[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.items = DataStore.getShopping();
  }

  build() {
    Column() {
      Row() {
        Text('当日基础菜价参考（区间按市场波动 ±15%）')
          .fontSize(12).fontColor($r('app.color.text_tertiary'))
        Blank()
        Text('清除已购')
          .fontSize(13).fontColor($r('app.color.accent'))
          .onClick((): void => {
            DataStore.clearCheckedShopping();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + NAV_TITLE_HEIGHT + 8, bottom: 12 })

      if (this.items.length === 0) {
        Column({ space: 10 }) {
          Text('暂无采购清单').fontSize(16).fontColor($r('app.color.text_secondary'))
          Text('在「点菜」生成菜单后，一键生成按人数折算的采购清单').fontSize(13).fontColor($r('app.color.text_tertiary'))
        }
        .width('100%').padding({ top: 60 })
      } else {
        List({ scroller: this.pageScroller, space: 10 }) {
          ForEach(this.items, (item: ShoppingItem): void => {
            ListItem() {
              Row({ space: 12 }) {
                Toggle({ type: ToggleType.Checkbox, isOn: item.checked })
                  .selectedColor($r('app.color.accent'))
                  .onChange((on: boolean): void => {
                    item.checked = on;
                    DataStore.setShopping(this.items);
                  })
                Column({ space: 3 }) {
                  Row({ space: 8 }) {
                    Text(item.name).fontSize(16)
                      .fontColor(item.checked ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
                      .decoration({ type: item.checked ? TextDecorationType.LineThrough : TextDecorationType.None })
                    Text(item.category)
                      .fontSize(10).fontColor($r('app.color.accent'))
                      .backgroundColor($r('app.color.accent_soft'))
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      .borderRadius(6)
                  }
                  Text(item.unit === '克'
                    ? `${item.amount >= 1000 ? (item.amount / 1000).toFixed(1) + ' kg' : item.amount + ' 克'}`
                    : `${item.amount} ${item.unit}`)
                    .fontSize(13).fontColor($r('app.color.text_secondary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Column({ space: 3 }) {
                  Text(`¥${item.priceLow} ~ ${item.priceHigh}`)
                    .fontSize(14).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium)
                  Text('参考价').fontSize(11).fontColor($r('app.color.text_tertiary'))
                }
              }
              .width('100%')
              .padding(14)
              .borderRadius(14)
              .backgroundColor($r('app.color.card_background'))
            }
          }, (item: ShoppingItem): string => `${item.name}_${item.checked}_${this.shoppingRev}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 120 })
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
  }
}