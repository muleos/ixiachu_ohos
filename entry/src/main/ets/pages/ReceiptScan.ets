/** 拍购物小票 → OCR 识别 → 解析食材入库（可编辑确认） */
import { router, promptAction } from '@kit.ArkUI';
import { StockItem } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { ReceiptParser } from '../service/ReceiptParser';
import { queryStatusBarHeight } from '../utils/Theme';

const SAMPLE_RECEIPT: string = `永辉超市 购物小票
2026-10-15 08:32
西红柿 1.25kg 9.90
土豆 2kg 7.96
五花肉 0.6kg 26.40
鸡蛋 1份 12.90
小葱 1份 2.00`;

@Entry
@Component
struct ReceiptScan {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  /** 页面挂载时直接查窗口避让区得到的状态栏高度（广播滞后/失败时的自查兜底） */
  @State queriedBar: number = 0;
  @State rawText: string = '';
  @State items: StockItem[] = [];
  @State scanning: boolean = false;

  aboutToAppear(): void {
    queryStatusBarHeight(getContext(this)).then((h: number): void => {
      if (h > 0) {
        this.queriedBar = h;
      }
    });
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
        Text('小票识别入库')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .padding({ left: 12, right: 20, top: Math.max(Math.max(this.statusBarHeight, this.queriedBar), 36) })

      Row({ space: 12 }) {
        Button(this.scanning ? '识别中…' : '拍照 / 选图识别')
          .layoutWeight(2).height(44).borderRadius(22)
          .backgroundColor($r('app.color.accent'))
          .fontColor(Color.White)
          .enabled(!this.scanning)
          .onClick((): void => {
            this.doScan();
          })
        Button('示例')
          .layoutWeight(1).height(44).borderRadius(22)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick((): void => {
            this.applyText(SAMPLE_RECEIPT);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })

      TextArea({ placeholder: '识别结果（可手动修正后再入库）', text: this.rawText })
        .width('100%')
        .height(140)
        .margin({ left: 20, right: 20, top: 12 })
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .onChange((v: string): void => {
          this.rawText = v;
          this.items = ReceiptParser.parseText(v);
        })

      Text(`识别到 ${this.items.length} 项食材（默认按采购日 = 今天入库）`)
        .fontSize(12).fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .padding({ left: 20, top: 12 })

      List({ space: 8 }) {
        ForEach(this.items, (it: StockItem): void => {
          ListItem() {
            Row({ space: 10 }) {
              Text(it.name).fontSize(15).fontColor($r('app.color.text_primary'))
              Text(it.category).fontSize(10).fontColor($r('app.color.accent'))
                .backgroundColor($r('app.color.accent_soft'))
                .padding({ left: 6, right: 6, top: 1, bottom: 1 }).borderRadius(6)
              Blank()
              Text(it.unit === '克' && it.amount >= 1000 ? (it.amount / 1000).toFixed(2) + ' kg' : `${it.amount} ${it.unit}`)
                .fontSize(13).fontColor($r('app.color.text_secondary'))
            }
            .width('100%').padding(12)
            .borderRadius(12).backgroundColor($r('app.color.card_background'))
          }
        }, (it: StockItem): string => `${it.id}_${it.name}_${it.amount}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 20 })

      Button(`确认入库（${this.items.length} 项）`)
        .width('calc(100% - 40vp)')
        .height(46).borderRadius(23).margin({ bottom: 20 })
        .backgroundColor($r('app.color.accent'))
        .fontColor(Color.White)
        .onClick((): void => {
          if (this.items.length === 0) {
            promptAction.showToast({ message: '没有可入库的食材' });
            return;
          }
          DataStore.addStock(this.items);
          promptAction.showToast({ message: `已入库 ${this.items.length} 项食材` });
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  private async doScan(): Promise<void> {
    this.scanning = true;
    try {
      const text: string = await ReceiptParser.scanReceipt();
      if (text.length === 0) {
        promptAction.showToast({ message: '未选择图片' });
      } else {
        this.applyText(text);
      }
    } catch (e) {
      const msg: string = (e as Error).message ?? '';
      promptAction.showToast({
        message: msg.length > 0 ? `识别失败：${msg}` : '识别失败，请检查相册权限或手动粘贴小票文本'
      });
    }
    this.scanning = false;
  }

  private applyText(text: string): void {
    this.rawText = text;
    this.items = ReceiptParser.parseText(text);
    if (this.items.length === 0 && text.trim().length > 0) {
      promptAction.showToast({ message: '未能从文本中解析出食材行，可手动删改文本（保留「品名 数量 价格」行）后重试' });
    }
  }
}
