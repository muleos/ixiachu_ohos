/** 拍购物小票 → OCR 识别 → 解析食材入库（可编辑确认，支持拍照/相册、品名改名沉淀、单价显示） */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { StockItem } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { ReceiptParser } from '../service/ReceiptParser';
import { lookupFood } from '../service/NutritionDB';
import { WidgetSync } from '../service/WidgetSync';
import { FrostPage } from '../components/FrostPage';

const SAMPLE_RECEIPT: string = `永辉超市 购物小票
2026-10-15 08:32
西红柿 1.25kg 9.90
土豆 2kg 7.96
五花肉 0.6kg 26.40
鸡蛋 1份 12.90
小葱 1份 2.00`;

/** 列表行模型：类目标题行 / 食材条目行（单 ForEach 交错渲染） */
class ReceiptRow {
  isHeader: boolean = false;
  cat: string = '';
  item: StockItem = new StockItem();
}

/** 分组展示的固定类目顺序 */
const GROUP_ORDER: string[] = ['叶菜', '根茎', '蛋类', '水产', '豆制品', '菌菇', '调味菜', '其他'];

@Entry
@Component
struct ReceiptScan {
  private scroller: Scroller = new Scroller();
  @State rawText: string = '';
  @State items: StockItem[] = [];
  @State scanning: boolean = false;
  @State renaming: StockItem | null = null;
  @State renameText: string = '';

  build() {
    Stack() {
      FrostPage({ title: '小票识别入库', scroller: this.scroller }) {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Button(this.scanning ? '识别中…' : '拍照识别')
              .layoutWeight(1).height(44).borderRadius(22)
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .fontSize(15)
              .enabled(!this.scanning)
              .onClick((): void => {
                this.doCapture();
              })
            Button('相册选图')
              .layoutWeight(1).height(44).borderRadius(22)
              .backgroundColor($r('app.color.accent_soft'))
              .fontColor($r('app.color.accent'))
              .fontSize(15)
              .enabled(!this.scanning)
              .onClick((): void => {
                this.doScan();
              })
            Button('示例')
              .height(44).borderRadius(22)
              .backgroundColor($r('app.color.card_background'))
              .fontColor($r('app.color.text_secondary'))
              .fontSize(14)
              .enabled(!this.scanning)
              .onClick((): void => {
                this.applyText(SAMPLE_RECEIPT);
              })
          }
          .width('100%')

          TextArea({ placeholder: '识别结果（可手动修正后再入库）', text: this.rawText })
            .width('100%')
            .height(140)
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .onChange((v: string): void => {
              this.rawText = v;
              this.items = ReceiptParser.parseText(v);
            })

          if (this.items.length > 0) {
            Text('点品名可改名；改错名会自动学习，下次识别自动纠正')
              .fontSize(11).fontColor($r('app.color.text_tertiary'))
              .width('100%')
          }

          // 解析结果（分组交错，随页面滚动）
          ForEach(this.rows(), (r: ReceiptRow): void => {
            if (r.isHeader) {
              Text(r.cat)
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding({ left: 4, top: 4 })
            } else {
              Row({ space: 8 }) {
                Text(r.item.name)
                  .fontSize(15).fontColor($r('app.color.text_primary'))
                  .constraintSize({ maxWidth: '42%' })
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick((): void => {
                    this.renaming = r.item;
                    this.renameText = r.item.name;
                  })
                Text(this.priceText(r.item))
                  .fontSize(12)
                  .fontColor(r.item.pricePerKg > 0 || r.item.pricePerUnit > 0
                    ? $r('app.color.accent') : $r('app.color.text_tertiary'))
                Blank()
                Text(r.item.unit === '克' && r.item.amount >= 1000
                  ? (r.item.amount / 1000).toFixed(2) + ' kg' : `${r.item.amount} ${r.item.unit}`)
                  .fontSize(13).fontColor($r('app.color.text_secondary'))
              }
              .width('100%').padding(12)
              .borderRadius(12).backgroundColor($r('app.color.card_background'))
            }
          }, (r: ReceiptRow): string => r.isHeader
            ? `h_${r.cat}`
            : `i_${r.item.id}_${r.item.name}_${r.item.amount}`)

          Button(`确认入库（${this.items.length} 项）`)
            .width('100%')
            .height(46).borderRadius(23)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .onClick((): void => {
              if (this.items.length === 0) {
                promptAction.showToast({ message: '没有可入库的食材' });
                return;
              }
              DataStore.addStock(this.items);
              DataStore.addLocalPrices(this.items);
              WidgetSync.updateAll();
              promptAction.showToast({ message: `已入库 ${this.items.length} 项食材（单价已计入本地菜价参考）` });
              router.back();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }

      // 改名弹层：全屏半透明遮罩 + 居中卡片；改名后沉淀为别名
      if (this.renaming !== null) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.4)')
          .onClick((): void => {
            this.renaming = null;
          })
        Column({ space: 14 }) {
          Text('修改品名').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          TextInput({ text: this.renameText, placeholder: '识别为「番茄」可改成「西红柿」' })
            .height(44).fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .backgroundColor($r('app.color.page_background'))
            .borderRadius(12)
            .onChange((v: string): void => {
              this.renameText = v;
            })
          Text('确认后此叫法会与原名建立关联，以后识别自动归一')
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
          Row({ space: 10 }) {
            Button('取消').fontSize(14).height(38).borderRadius(19).layoutWeight(1)
              .backgroundColor($r('app.color.page_background'))
              .fontColor($r('app.color.text_secondary'))
              .onClick((): void => {
                this.renaming = null;
              })
            Button('保存').fontSize(14).height(38).borderRadius(19).layoutWeight(1)
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .onClick((): void => {
                const it: StockItem = this.renaming as StockItem;
                const newName: string = this.renameText.trim();
                if (newName.length > 0 && newName !== it.name) {
                  const oldName: string = it.name;
                  it.name = newName;
                  DataStore.learnAlias(newName, oldName);
                  // 归一名重查知识库，类目与保鲜期随之修正
                  const info = lookupFood(newName);
                  it.category = info !== null ? info.category : '其他';
                  it.baseShelfDays = info !== null ? info.shelfDays : 7;
                  this.items = this.items.slice();
                }
                this.renaming = null;
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
  }

  /** 单价展示：重量类元/kg，计数类元/件 */
  private priceText(it: StockItem): string {
    if (it.pricePerKg > 0) {
      return `${it.pricePerKg.toFixed(2)}元/kg`;
    }
    if (it.pricePerUnit > 0) {
      return `${it.pricePerUnit.toFixed(2)}元/件`;
    }
    return '无价';
  }

  /** 按类目分组展开成「标题行+条目行」交错列表 */
  private rows(): ReceiptRow[] {
    const map: Map<string, StockItem[]> = new Map<string, StockItem[]>();
    for (const it of this.items) {
      const list: StockItem[] | undefined = map.get(it.category);
      if (list === undefined) {
        map.set(it.category, [it]);
      } else {
        list.push(it);
      }
    }
    const cats: string[] = [];
    for (const cat of GROUP_ORDER) {
      if (map.has(cat)) {
        cats.push(cat);
        map.delete(cat);
      }
    }
    // 数据库里出现但未列入固定顺序的类目，按名称追加
    cats.push(...Array.from(map.keys()).sort());
    const out: ReceiptRow[] = [];
    for (const cat of cats) {
      const head: ReceiptRow = new ReceiptRow();
      head.isHeader = true;
      head.cat = cat;
      out.push(head);
      for (const it of map.get(cat) as StockItem[]) {
        const row: ReceiptRow = new ReceiptRow();
        row.item = it;
        out.push(row);
      }
    }
    return out;
  }

  private async doCapture(): Promise<void> {
    this.scanning = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const path: string = await ReceiptParser.captureReceipt(ctx);
      if (path.length === 0) {
        promptAction.showToast({ message: '未拍摄照片' });
      } else {
        const text: string = await ReceiptParser.recognizeFromPath(path);
        this.applyText(text);
      }
    } catch (e) {
      const msg: string = (e as Error).message ?? '';
      promptAction.showToast({
        message: msg.length > 0 ? `识别失败：${msg}` : '识别失败，请重试或手动粘贴小票文本'
      });
    }
    this.scanning = false;
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
