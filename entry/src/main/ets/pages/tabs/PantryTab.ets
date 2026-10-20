/** 功能四：食材管理 —— 小票识别入库 / 新鲜度(气温+储存状态) / 手动校准 / 消耗记录 */
import { router } from '@kit.ArkUI';
import { ConsumeRecord, FreshLevel, StockItem } from '../../model/Models';
import { DataStore } from '../../service/DataStore';
import { Freshness } from '../../service/Freshness';
import { Weather } from '../../service/Weather';
import { topAvoid } from '../../utils/Theme';
import { WidgetSync } from '../../service/WidgetSync';
import { GlassPill } from '../../components/GlassPill';

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
  @State editStorage: string = '冷藏';
  /** 当前气候系数（先月份代理，气温拉到后热更新） */
  @State climate: number = Freshness.monthFactor(new Date());
  /** 气温提示文案（空表示月份代理） */
  @State climateText: string = '';
  @State showCity: boolean = false;

  aboutToAppear(): void {
    this.reload();
    this.refreshClimate();
  }

  build() {
    Stack() {
      // v1.9.0 沉浸光感：操作行并入列表首项，内容透出到标题栏后面
      List({ scroller: this.pageScroller, space: 10 }) {
        // 首项：避让 spacer + 气温提示 / 操作按钮行
        ListItem() {
          Row() {
            Text(this.hintText())
              .fontSize(12).fontColor(this.soonCount() > 0 ? $r('app.color.tag_orange') : $r('app.color.text_tertiary'))
              .layoutWeight(1)
              .onClick((): void => {
                this.showCity = !this.showCity;
              })
            GlassPill({
              icon: $r('sys.symbol.square_and_pencil'),
              label: '手动录入',
              onTap: (): void => {
                router.pushUrl({ url: 'pages/StockManual' });
              }
            })
            GlassPill({
              icon: $r('sys.symbol.picture'),
              label: '拍小票入库',
              onTap: (): void => {
                router.pushUrl({ url: 'pages/ReceiptScan' });
              }
            }).margin({ left: 10 })
            GlassPill({
              icon: $r('sys.symbol.gearshape'),
              fixedWidth: 52,
              onTap: (): void => {
                router.pushUrl({ url: 'pages/Settings' });
              }
            }).margin({ left: 10 })
          }
          .width('100%')
          .padding({ top: topAvoid(this.statusBarHeight) + 8, bottom: 4 })
        }

        if (this.stock.length === 0) {
          ListItem() {
            Column({ space: 10 }) {
              Text('冰箱空空如也').fontSize(16).fontColor($r('app.color.text_secondary'))
              Text('拍摄购物小票，自动识别食材种类与数量入库').fontSize(13).fontColor($r('app.color.text_tertiary'))
            }
            .width('100%').padding({ top: 40 })
          }
        } else {
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
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: 92 })
      .edgeEffect(EdgeEffect.Spring)
      // 悬浮层（校准/城市弹层）仍在 Stack 内，Stack 于 build 尾部闭合

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
        Text('剩余量').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          .width('100%')
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
        Text('储存状态（影响新鲜度估算：常温折半、冷冻大幅延长）').fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary')).width('100%')
        Row({ space: 8 }) {
          ForEach(['常温', '冷藏', '冷冻'], (st: string): void => {
            Button(st).fontSize(13).height(34).borderRadius(17).layoutWeight(1)
              .fontColor(this.editStorage === st ? Color.White : $r('app.color.text_secondary'))
              .backgroundColor(this.editStorage === st ? $r('app.color.accent') : $r('app.color.page_background'))
              .onClick((): void => {
                this.editStorage = st;
              })
          }, (st: string): string => st)
        }
        .width('100%')
        Text(`单位：${(this.editing as StockItem).unit}；数量填 0 视为用完并移除`)
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
                DataStore.updateStockAmount((this.editing as StockItem).id, v, this.editStorage);
                WidgetSync.updateAll();
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
    // 城市切换弹层（气温系数按城市取）
    if (this.showCity) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick((): void => {
          this.showCity = false;
        })
      Column({ space: 12 }) {
        Text('选择城市（用于气温修正新鲜度）').fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary')).width('100%')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(Weather.cities(), (c: string): void => {
            Button(c).fontSize(13).height(32).borderRadius(16)
              .margin({ right: 8, bottom: 8 })
              .fontColor(Weather.currentCity() === c ? Color.White : $r('app.color.text_secondary'))
              .backgroundColor(Weather.currentCity() === c ? $r('app.color.accent') : $r('app.color.page_background'))
              .onClick((): void => {
                Weather.setCity(c);
                this.showCity = false;
                this.climateText = '';
                this.refreshClimate();
              })
          }, (c: string): string => c)
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
    .width('100%')
    .height('100%')
  }

  private reload(): void {
    this.stock = Freshness.snapshotWith(this.climate);
    this.consume = DataStore.getConsumeLog();
  }

  /** 拉实时气温热更新气候系数（失败静默保持月份代理） */
  private async refreshClimate(): Promise<void> {
    const f: number = await Weather.climateFactor(new Date());
    if (Math.abs(f - this.climate) > 0.01 || this.climateText.length === 0) {
      this.climate = f;
      this.reload();
    }
    this.climateText = Weather.hintText();
  }

  /** 顶部提示：临期优先，其次气温状态 */
  private hintText(): string {
    if (this.soonCount() > 0) {
      return `${this.soonCount()} 项食材临期，建议优先食用${this.climateText.length > 0 ? ` · ${this.climateText}` : ''}`;
    }
    return this.climateText.length > 0
      ? `${this.climateText} · 点菜时自动扣减库存（点此换城市）`
      : '按采购日期与气候估算新鲜程度；点菜时自动扣减库存';
  }

  /** 临期统计（建议尽快食用 + 建议评估丢弃） */
  private soonCount(): number {
    const now: Date = new Date();
    return this.stock.filter((s: StockItem): boolean =>
      Freshness.level(Freshness.decayRatioSync(s, now, this.climate)) >= FreshLevel.SOON).length;
  }

  @Builder
  StockCard(item: StockItem) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(item.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            if (item.storage !== '冷藏') {
              Text(item.storage === '冷冻' ? '❄ 冷冻' : '常温')
                .fontSize(10)
                .fontColor(item.storage === '冷冻' ? $r('app.color.accent') : $r('app.color.text_secondary'))
                .backgroundColor($r('app.color.page_background'))
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .borderRadius(5)
            }
          }
          Text(`${item.unit === '克' && item.amount >= 1000 ? (item.amount / 1000).toFixed(1) + ' kg' : item.amount + ' ' + item.unit} · ${item.category}`)
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 3 }) {
          Text(Freshness.levelText(Freshness.level(Freshness.decayRatioSync(item, new Date(), this.climate))))
            .fontSize(12).fontColor(Freshness.levelColor(Freshness.level(Freshness.decayRatioSync(item, new Date(), this.climate))))
            .fontWeight(FontWeight.Medium)
          Text(this.remainText(item))
            .fontSize(11).fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      Row({ space: 8 }) {
        Text(`采购于 ${this.dateText(item.buyDate)} · ${item.storage}${item.lastCalibrated > 0 ? ' · 已校准' : ''}`)
          .fontSize(11).fontColor($r('app.color.text_tertiary'))
        Blank()
        Button('用完了').fontSize(12).height(28).borderRadius(14)
          .backgroundColor($r('app.color.page_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick((): void => {
            DataStore.removeStock(item.id);
            WidgetSync.updateAll();
            this.reload();
          })
        Button('校准').fontSize(12).height(28).borderRadius(14)
          .backgroundColor($r('app.color.accent_soft'))
          .fontColor($r('app.color.accent'))
          .onClick((): void => {
            this.editing = item;
            this.editAmount = `${item.amount}`;
            this.editStorage = item.storage;
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
    const d: number = Freshness.remainDaysSync(item, new Date(), this.climate);
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
