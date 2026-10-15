/** 功能四：食材管理 —— 小票识别入库 / 新鲜度 / 手动校准 / 库存优先推荐 / 消耗记录 */
import { router } from '@kit.ArkUI';
import { ConsumeRecord, FreshLevel, StockItem } from '../../model/Models';
import { DataStore } from '../../service/DataStore';
import { Freshness } from '../../service/Freshness';
import { topAvoid } from '../../utils/Theme';

@Component
export struct PantryTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('dataRev') @Watch('reload') dataRev: number = 0;
  @State stock: StockItem[] = [];
  @State consume: ConsumeRecord[] = [];
  @State showConsume: boolean = false;
  @State editing: StockItem | null = null;
  @State editAmount: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text(this.soonCount() > 0 ? `${this.soonCount()} 项食材临期，建议优先食用` : '按采购日期与气候估算新鲜程度；点菜时自动扣减库存')
            .fontSize(12).fontColor(this.soonCount() > 0 ? $r('app.color.tag_orange') : $r('app.color.text_tertiary'))
            .layoutWeight(1)
        Button() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(16).fontColor([$r('app.color.accent')])
            Text('手动录入').fontSize(14).fontColor($r('app.color.accent'))
          }
        }
        .backgroundColor($r('app.color.accent_soft'))
        .height(36)
        .borderRadius(18)
        .onClick((): void => {
          router.pushUrl({ url: 'pages/StockManual' });
        })
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

          // 近期消耗（点菜扣减记录，可折叠）
          if (this.consume.length > 0) {
            ListItem() {
              Column({ space: 8 }) {
                Row({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.clock')).fontSize(14).fontColor([$r('app.color.text_secondary')])
                  Text(`近期消耗（${this.consume.length}）`).fontSize(14).fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Blank()
                  SymbolGlyph(this.showConsume ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
                    .fontSize(14).fontColor([$r('app.color.text_tertiary')])
                }
                .width('100%')
                .onClick((): void => {
                  this.showConsume = !this.showConsume;
                })
                if (this.showConsume) {
                  ForEach(this.consume.slice(0, 10), (c: ConsumeRecord): void => {
                    Row({ space: 8 }) {
                      Text(c.date.substring(5)).fontSize(12).fontColor($r('app.color.text_tertiary'))
                      Text(`${c.recipeName} · ${c.foodName}`).fontSize(13).fontColor($r('app.color.text_primary'))
                        .layoutWeight(1)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`-${c.amount} ${c.unit}`).fontSize(13).fontColor($r('app.color.accent'))
                    }
                    .width('100%').padding({ top: 4, bottom: 4 })
                  }, (c: ConsumeRecord): string => c.id)
                  Text('点菜确认后按菜谱用量自动扣减；数量不符时可在上方校准')
                    .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
                }
              }
              .width('100%').padding(14)
              .borderRadius(14)
              .backgroundColor($r('app.color.card_background'))
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 120 })
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')

    // 校准弹层：全屏半透明遮罩 + 居中卡片；点遮罩关闭
    if (this.editing !== null) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick((): void => {
          this.editing = null;
        })
      Column({ space: 14 }) {
        Text(`校准「${(this.editing as StockItem).name}」剩余量`).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        TextInput({ text: this.editAmount, placeholder: `当前 ${(this.editing as StockItem).amount} ${(this.editing as StockItem).unit}` })
          .type(InputType.NUMBER_DECIMAL)
          .height(44).fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(12)
          .onChange((v: string): void => {
            this.editAmount = v;
          })
        Text(`单位：${(this.editing as StockItem).unit}；填 0 视为用完并移除`)
          .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
        Row({ space: 10 }) {
          Button('取消').fontSize(14).height(38).borderRadius(19).layoutWeight(1)
            .backgroundColor($r('app.color.page_background'))
            .fontColor($r('app.color.text_secondary'))
            .onClick((): void => {
              this.editing = null;
            })
          Button('保存校准').fontSize(14).height(38).borderRadius(19).layoutWeight(1)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .onClick((): void => {
              const v: number = parseFloat(this.editAmount);
              if (!isNaN(v)) {
                DataStore.updateStockAmount((this.editing as StockItem).id, v);
                this.reload();
              }
              this.editing = null;
            })
        }
        .width('100%')
      }
      .padding(20)
      .margin({ left: 32, right: 32 })
      .borderRadius(18)
      .backgroundColor($r('app.color.card_background'))
      .width('100%')
      .onClick((): void => {
        // 阻断冒泡，避免点弹窗内容关闭
      })
    }
  }

  private reload(): void {
    this.stock = Freshness.snapshot();
    this.consume = DataStore.getConsumeLog();
  }

  /** 临期统计（建议尽快食用 + 建议评估丢弃） */
  private soonCount(): number {
    const now: Date = new Date();
    return this.stock.filter((s: StockItem): boolean =>
      Freshness.level(Freshness.decayRatio(s, now)) >= FreshLevel.SOON).length;
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
        Text(`采购于 ${this.dateText(item.buyDate)}${item.lastCalibrated > 0 ? ' · 已校准' : ''}`)
          .fontSize(11).fontColor($r('app.color.text_tertiary'))
        Blank()
        Button('用完了').fontSize(12).height(28).borderRadius(14)
          .backgroundColor($r('app.color.page_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick((): void => {
            DataStore.removeStock(item.id);
            this.reload();
          })
        Button('校准').fontSize(12).height(28).borderRadius(14)
          .backgroundColor($r('app.color.accent_soft'))
          .fontColor($r('app.color.accent'))
          .onClick((): void => {
            this.editing = item;
            this.editAmount = `${item.amount}`;
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
