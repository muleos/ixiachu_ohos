/** 功能四：食材管理 —— 小票识别入库 / 新鲜度 / 手动校准 / 库存优先推荐 */
import { router } from '@kit.ArkUI';
import { StockItem } from '../../model/Models';
import { DataStore } from '../../service/DataStore';
import { Freshness } from '../../service/Freshness';
import { topAvoid } from '../../utils/Theme';

@Component
export struct PantryTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('dataRev') @Watch('reload') dataRev: number = 0;
  @State stock: StockItem[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  build() {
    Column() {
      Row() {
        Text('按采购日期与气候估算新鲜程度；点菜时自动优先消耗剩余食材')
          .fontSize(12).fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
        Button() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.picture')).fontSize(16).fontColor([$r('app.color.accent')])
            Text('拍小票入库').fontSize(14).fontColor($r('app.color.accent'))
          }
        }
        .backgroundColor($r('app.color.accent_soft'))
        .height(36)
        .borderRadius(18)
        .margin({ left: 10 })
        .onClick((): void => {
          router.pushUrl({ url: 'pages/ReceiptScan' });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: topAvoid(this.statusBarHeight) + 8, bottom: 12 })

      if (this.stock.length === 0) {
        Column({ space: 10 }) {
          Text('冰箱空空如也').fontSize(16).fontColor($r('app.color.text_secondary'))
          Text('拍摄购物小票，自动识别食材种类与数量入库').fontSize(13).fontColor($r('app.color.text_tertiary'))
        }
        .width('100%').padding({ top: 60 })
      } else {
        List({ scroller: this.pageScroller, space: 10 }) {
          ForEach(this.stock, (item: StockItem): void => {
            ListItem() {
              this.StockCard(item)
            }
          }, (item: StockItem): string => `${item.id}_${this.dataRev}_${item.amount}`)
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

  private reload(): void {
    this.stock = Freshness.snapshot();
  }

  @Builder
  StockCard(item: StockItem) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(item.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          Text(`${item.unit === '克' && item.amount >= 1000 ? (item.amount / 1000).toFixed(1) + ' kg' : item.amount + ' ' + item.unit} · ${item.category}`)
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 3 }) {
          Text(Freshness.levelText(Freshness.level(Freshness.decayRatio(item, new Date()))))
            .fontSize(12).fontColor(Freshness.levelColor(Freshness.level(Freshness.decayRatio(item, new Date()))))
            .fontWeight(FontWeight.Medium)
          Text(this.remainText(item))
            .fontSize(11).fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      Row({ space: 8 }) {
        Text(`采购于 ${this.dateText(item.buyDate)}`).fontSize(11).fontColor($r('app.color.text_tertiary'))
        Blank()
        Button('用完了').fontSize(12).height(28).borderRadius(14)
          .backgroundColor($r('app.color.page_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick((): void => {
            DataStore.removeStock(item.id);
            this.reload();
          })
        Button('校准减半').fontSize(12).height(28).borderRadius(14)
          .backgroundColor($r('app.color.accent_soft'))
          .fontColor($r('app.color.accent'))
          .onClick((): void => {
            item.amount = Math.max(0, Math.round(item.amount / 2));
            item.calibratedRatio = 1;
            DataStore.setStock(DataStore.getStock());
            this.reload();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.card_background'))
  }

  private remainText(item: StockItem): string {
    const d: number = Freshness.remainDays(item, new Date());
    if (d <= 0) {
      return '今天内食用';
    }
    return `还可存约 ${d} 天`;
  }

  private dateText(ts: number): string {
    const d: Date = new Date(ts);
    return `${d.getMonth() + 1}月${d.getDate()}日`;
  }
}
