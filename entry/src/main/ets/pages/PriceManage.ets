/**
 * 价格记录管理（v1.12.3）：本地食材单价的录入 / 编辑 / 删除。
 * 数据源与超市小票采集同一张价库（元/千克，按日去重，保留最近 N 条）。
 */
import { router, promptAction } from '@kit.ArkUI';
import { LocalPricePoint } from '../service/DataStore';
import { DataStore } from '../service/DataStore';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct PriceManage {
  private scroller: Scroller = new Scroller();
  @State names: string[] = [];
  /** 展开的食材（查看历史采集点） */
  @State expanded: string = '';
  @State newName: string = '';
  @State newPrice: string = '';
  /** 编辑态：name → 今日价输入 */
  @State editName: string = '';
  @State editPrice: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.names = DataStore.localPriceNames();
  }

  private latestPrice(name: string): string {
    const list: LocalPricePoint[] = DataStore.localPricesOf(name);
    if (list.length === 0) {
      return '—';
    }
    return `${list[0].p.toFixed(2)} 元/kg`;
  }

  private saveNew(): void {
    const name: string = this.newName.trim();
    const price: number = parseFloat(this.newPrice);
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入食材名称' });
      return;
    }
    if (isNaN(price) || price <= 0) {
      promptAction.showToast({ message: '请输入有效单价（元/千克）' });
      return;
    }
    DataStore.setLocalPrice(name, price);
    this.newName = '';
    this.newPrice = '';
    this.reload();
    promptAction.showToast({ message: `已记录：${name} ${price.toFixed(2)} 元/kg` });
  }

  private saveEdit(): void {
    const price: number = parseFloat(this.editPrice);
    if (isNaN(price) || price <= 0) {
      promptAction.showToast({ message: '请输入有效单价（元/千克）' });
      return;
    }
    DataStore.setLocalPrice(this.editName, price);
    this.editName = '';
    this.editPrice = '';
    this.reload();
  }

  build() {
    Stack() {
    FrostPage({ title: '价格记录', subtitle: '食材单价录入与编辑（元/千克）', scroller: this.scroller }) {
      Column({ space: 14 }) {
        // 录入卡
        Column({ space: 10 }) {
          Text('录入今日价').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          Row({ space: 10 }) {
            TextInput({ placeholder: '食材名称（如：西红柿）', text: this.newName })
              .layoutWeight(1)
              .height(40).fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((v: string): void => {
                this.newName = v;
              })
          }
          .width('100%')
          Row({ space: 10 }) {
            TextInput({ placeholder: '单价（元/千克，如：9.90）', text: this.newPrice })
              .layoutWeight(1)
              .height(40).fontSize(14).type(InputType.NUMBER_DECIMAL)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((v: string): void => {
                this.newPrice = v;
              })
            Button('保存')
              .height(40).borderRadius(20)
              .padding({ left: 20, right: 20 })
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .fontSize(14)
              .onClick((): void => {
                this.saveNew();
              })
          }
          .width('100%')
          Text('同一天重复保存会覆盖；采购清单与总金额将优先使用这里的实付价')
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
        }
        .width('100%').padding(16).borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .alignItems(HorizontalAlign.Start)

        // 记录列表
        if (this.names.length === 0) {
          Text('还没有价格记录，先录入一条吧')
            .fontSize(13).fontColor($r('app.color.text_tertiary')).width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 20 })
        }
        ForEach(this.names, (name: string): void => {
          Column({ space: 8 }) {
            // 食材行：名称 + 最新价 + 展开/收起
            Row({ space: 10 }) {
              Text(name)
                .fontSize(15).fontColor($r('app.color.text_primary'))
                .constraintSize({ maxWidth: '40%' })
                .maxLines(1)
              Text(this.latestPrice(name))
                .fontSize(13).fontColor($r('app.color.accent'))
              Blank()
              Row({ space: 4 }) {
                Text(this.expanded === name ? '收起' : '历史')
                  .fontSize(12).fontColor($r('app.color.text_tertiary'))
                SymbolGlyph($r('sys.symbol.chevron_down'))
                  .fontSize(11).fontColor([$r('app.color.text_tertiary')])
                  .rotate({ angle: this.expanded === name ? 180 : 0 })
              }
              .onClick((): void => {
                this.expanded = this.expanded === name ? '' : name;
              })
            }
            .width('100%')

            // 编辑今日价（快捷改价）
            if (this.editName === name) {
              Row({ space: 10 }) {
                TextInput({ placeholder: '改为今日新价（元/千克）', text: this.editPrice })
                  .layoutWeight(1)
                  .height(38).fontSize(13).type(InputType.NUMBER_DECIMAL)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .backgroundColor($r('app.color.page_background'))
                  .borderRadius(10)
                  .onChange((v: string): void => {
                    this.editPrice = v;
                  })
                Button('改价')
                  .height(38).borderRadius(19)
                  .padding({ left: 16, right: 16 })
                  .backgroundColor($r('app.color.accent'))
                  .fontColor(Color.White)
                  .fontSize(13)
                  .onClick((): void => {
                    this.saveEdit();
                  })
              }
              .width('100%')
            } else {
              Text('改今日价 ›')
                .fontSize(12).fontColor($r('app.color.accent'))
                .onClick((): void => {
                  this.editName = name;
                  this.editPrice = '';
                })
            }

            // 历史采集点（展开时）
            if (this.expanded === name) {
              Column({ space: 6 }) {
                ForEach(DataStore.localPricesOf(name), (p: LocalPricePoint, i: number): void => {
                  Row({ space: 10 }) {
                    Text(p.d).fontSize(12).fontColor($r('app.color.text_tertiary'))
                    Blank()
                    Text(`${p.p.toFixed(2)} 元/kg`).fontSize(12).fontColor($r('app.color.text_secondary'))
                    SymbolGlyph($r('sys.symbol.trash'))
                      .fontSize(13)
                      .fontColor([$r('app.color.text_tertiary')])
                      .onClick((): void => {
                        DataStore.removeLocalPrice(name, i);
                        this.reload();
                      })
                  }
                  .width('100%')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .borderRadius(8)
                  .backgroundColor($r('app.color.page_background'))
                }, (p: LocalPricePoint): string => `${p.d}_${p.p}`)
              }
              .width('100%')
            }
          }
          .width('100%').padding(14).borderRadius(14)
          .backgroundColor($r('app.color.card_background'))
          .alignItems(HorizontalAlign.Start)
        }, (name: string): string => name)

        Column().width('100%').height(20)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    }
  }
}
