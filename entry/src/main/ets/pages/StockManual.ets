/** 手动录入食材：不拍小票也能把食材加进库存（名称 + 数量 + 单位） */
import { router, promptAction } from '@kit.ArkUI';
import { StockItem } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { FoodInfo, lookupFood } from '../service/NutritionDB';
import { queryStatusBarHeight } from '../utils/Theme';

const UNITS: string[] = ['克', '份', '个', '盒', '瓶', '袋', '把', '根'];

@Entry
@Component
struct StockManual {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @State queriedBar: number = 0;
  @State name: string = '';
  @State amount: string = '';
  @State unit: string = '克';
  @State storage: string = '冷藏';

  aboutToAppear(): void {
    queryStatusBarHeight(getContext(this)).then((h: number): void => {
      if (h > 0) {
        this.queriedBar = h;
      }
    });
  }

  private topBar(): number {
    return Math.max(Math.max(this.statusBarHeight, this.queriedBar), 36);
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
          .onClick((): void => {
            router.back();
          })
        Text('手动录入食材')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .padding({ left: 12, right: 20, top: this.topBar() })

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text('食材名称').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              .width('100%')
            TextInput({ placeholder: '如：西红柿、五花肉、鸡蛋', text: this.name })
              .height(44).fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(12)
              .onChange((v: string): void => {
                this.name = v;
              })
          }
          .width('100%').padding(16).borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('数量与单位').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              .width('100%')
            Row({ space: 10 }) {
              TextInput({ placeholder: '数量', text: this.amount })
                .layoutWeight(1)
                .height(44).fontSize(15).type(InputType.NUMBER_DECIMAL)
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .backgroundColor($r('app.color.page_background'))
                .borderRadius(12)
                .onChange((v: string): void => {
                  this.amount = v;
                })
            }
            .width('100%')
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(UNITS, (u: string): void => {
                Text(u)
                  .fontSize(13)
                  .fontColor(this.unit === u ? Color.White : $r('app.color.text_secondary'))
                  .backgroundColor(this.unit === u ? $r('app.color.accent') : $r('app.color.page_background'))
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .borderRadius(16)
                  .margin({ right: 8, bottom: 8 })
                  .onClick((): void => {
                    this.unit = u;
                  })
              }, (u: string): string => u)
            }
            .width('100%')
            Text('储存状态').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              .width('100%').margin({ top: 4 })
            Row({ space: 8 }) {
              ForEach(['常温', '冷藏', '冷冻'], (st: string): void => {
                Button(st).fontSize(13).height(34).borderRadius(17).layoutWeight(1)
                  .fontColor(this.storage === st ? Color.White : $r('app.color.text_secondary'))
                  .backgroundColor(this.storage === st ? $r('app.color.accent') : $r('app.color.page_background'))
                  .onClick((): void => {
                    this.storage = st;
                  })
              }, (st: string): string => st)
            }
            .width('100%')
          }
          .width('100%').padding(16).borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .alignItems(HorizontalAlign.Start)

          Button('加入库存')
            .width('100%').height(46).borderRadius(23)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .onClick((): void => {
              this.save();
            })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  private save(): void {
    const n: string = this.name.trim();
    if (n.length === 0) {
      promptAction.showToast({ message: '请输入食材名称' });
      return;
    }
    const a: number = parseFloat(this.amount);
    if (isNaN(a) || a <= 0) {
      promptAction.showToast({ message: '请输入有效数量' });
      return;
    }
    const info: FoodInfo = lookupFood(n) as FoodInfo;
    const it: StockItem = new StockItem();
    it.id = `m${Date.now()}`;
    it.name = n;
    it.amount = this.unit === '克' ? Math.round(a) : a;
    it.unit = this.unit;
    it.category = info.category;
    it.buyDate = Date.now();
    it.baseShelfDays = info.shelfDays;
    it.storage = this.storage;
    DataStore.addStock([it]);
    promptAction.showToast({ message: `已入库：${n}` });
    router.back();
  }
}
