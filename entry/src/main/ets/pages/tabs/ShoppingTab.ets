/** 功能三：采购清单 —— 按点菜汇总 + 当日基础菜价参考区间 + 总金额/价格记录管理 */
import { router } from '@kit.ArkUI';
import { DataStore } from '../../service/DataStore';
import { ShoppingItem } from '../../model/Models';
import { topAvoid } from '../../utils/Theme';

@Component
export struct ShoppingTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  /** 采购清单专属广播键：@StorageLink 强绑定，生成/勾选/清除都会立即触发 reload */
  @StorageLink('shoppingRev') @Watch('reload') shoppingRev: number = 0;
  /** 列表用 @State 承载：非状态方法调用不会触发条件分支重渲染 */
  @State items: ShoppingItem[] = [];
  /** 云端菜价最近同步日期（空 = 尚未同步过，用内置基准价） */
  @State priceSyncDate: string = '';

  aboutToAppear(): void {
    this.reload();
    this.priceSyncDate = DataStore.getSetting('price_last_sync');
  }

  private reload(): void {
    // 调料/调味菜不进采购清单（存量清单也一并过滤）
    this.items = DataStore.getShopping().filter((it: ShoppingItem): boolean =>
      it.category !== '调料' && it.category !== '调味菜');
  }

  /** 价格来源说明：本地小票实付价优先展示，其次云端同步价，最后静态基准价 */
  private priceHint(): string {
    const localCount: number = DataStore.localPriceCount();
    const cloud: string = this.priceSyncDate.length > 0 ? `惠友到家（${this.priceSyncDate} 同步）` : '惠友超市 / 网络公开价';
    if (localCount > 0) {
      return `菜价参考：本地小票实付价 ${localCount} 项优先，其余按 ${cloud}（±15%）`;
    }
    return `菜价参考：${cloud}（±15%）`;
  }

  /** 数量展示：≥250g 按千克（2 位小数），其余按克/原单位 */
  private amountText(item: ShoppingItem): string {
    if (item.unit === '克') {
      return item.amount >= 250 ? `${(item.amount / 1000).toFixed(2)} kg` : `${item.amount} 克`;
    }
    return `${item.amount} ${item.unit}`;
  }

  /** 本次采购总金额（按各食材预计花费区间累计） */
  private totalLow(): number {
    let t: number = 0;
    for (const it of this.items) {
      t += it.priceLow;
    }
    return t;
  }

  private totalHigh(): number {
    let t: number = 0;
    for (const it of this.items) {
      t += it.priceHigh;
    }
    return t;
  }

  private totalText(): string {
    if (this.totalHigh() <= 0) {
      return '暂无价格参考，点「价格记录」补录';
    }
    return `本次采购预计 ¥${this.totalLow().toFixed(1)} ~ ¥${this.totalHigh().toFixed(1)}`;
  }

  build() {
    // v1.9.0 沉浸光感：提示行并入列表首项，内容透出到标题栏后面
    List({ scroller: this.pageScroller, space: 10 }) {
      // 首项：避让 spacer + 菜价参考/总金额/价格管理入口（随内容滚走）
      ListItem() {
        Column({ space: 8 }) {
          Row() {
            Text(this.priceHint())
              .fontSize(12).fontColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
            Text('清除已购')
              .fontSize(13).fontColor($r('app.color.accent'))
              .onClick((): void => {
                DataStore.clearCheckedShopping();
              })
          }
          .width('100%')

          Row() {
            Text(this.totalText())
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.totalHigh() > 0 ? $r('app.color.accent') : $r('app.color.text_tertiary'))
            Blank()
            Text('价格记录 ›')
              .fontSize(13).fontColor($r('app.color.accent'))
              .onClick((): void => {
                router.pushUrl({ url: 'pages/PriceManage' });
              })
          }
          .width('100%')
          .padding(12)
          .borderRadius(14)
          .backgroundColor($r('app.color.card_background'))
        }
        .width('100%')
        .padding({ top: topAvoid(this.statusBarHeight) + 8, bottom: 4 })
      }

      if (this.items.length === 0) {
        ListItem() {
          Column({ space: 10 }) {
            Text('暂无采购清单').fontSize(16).fontColor($r('app.color.text_secondary'))
            Text('在「点菜」生成菜单后，一键生成按人数折算的采购清单').fontSize(13).fontColor($r('app.color.text_tertiary'))
          }
          .width('100%').padding({ top: 40 })
        }
      } else {
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
                Text(this.amountText(item))
                  .fontSize(13).fontColor($r('app.color.text_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Column({ space: 3 }) {
                // 预计花费（本次所需量 × 单价 ±15%）
                Text(`预计 ¥${item.priceLow} ~ ${item.priceHigh}`)
                  .fontSize(14).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium)
                // 单价 + 所需量：250g 以上按千克显示
                if (item.pricePerKg > 0) {
                  Text(`¥${item.pricePerKg}/kg × ${this.amountText(item)}`)
                    .fontSize(11).fontColor($r('app.color.text_tertiary'))
                } else {
                  Text('参考价').fontSize(11).fontColor($r('app.color.text_tertiary'))
                }
              }
            }
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .backgroundColor($r('app.color.card_background'))
          }
        }, (item: ShoppingItem): string => `${item.name}_${item.checked}_${this.shoppingRev}`)
      }
      // 尾部 spacer：内容视口直达屏幕底（小白条沉浸，同点菜页）；
      // 滚到底时末卡恰好停在悬浮胶囊上沿
      ListItem() {
        Column().width('100%').height(92)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .edgeEffect(EdgeEffect.Spring)
  }
}