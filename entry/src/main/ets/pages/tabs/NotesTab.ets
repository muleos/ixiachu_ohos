/** 笔记 Tab（v1.12.1）—— 小红书式双列瀑布流：本地/解析的图文视频帖子，右上角发布与解析 */
import { router } from '@kit.ArkUI';
import { NoteItem } from '../../model/Models';
import { NoteStore } from '../../service/NoteStore';
import { topAvoid } from '../../utils/Theme';

const SPACER_H: number = 92;

@Component
export struct NotesTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('notesRev') @Watch('reload') notesRev: number = 0;
  @State notes: NoteItem[] = [];
  /** 双列累积高度（简易瀑布流分配） */
  @State leftCol: NoteItem[] = [];
  @State rightCol: NoteItem[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.notes = NoteStore.list().slice();
    // 按卡片高度贪心分配到较矮的一列（高度=图宽比换算 + 文字区估算）
    this.leftCol = [];
    this.rightCol = [];
    let lh: number = 0;
    let rh: number = 0;
    for (const n of this.notes) {
      const h: number = this.cardHeight(n);
      if (lh <= rh) {
        this.leftCol = this.leftCol.concat([n]);
        lh += h;
      } else {
        this.rightCol = this.rightCol.concat([n]);
        rh += h;
      }
    }
  }

  /** 卡片估算高度（等宽 160vp 口径，用于分配） */
  private cardHeight(n: NoteItem): number {
    let h: number = 14;
    if (n.mediaPaths.length > 0) {
      h += 160 * n.coverH / n.coverW;
    } else if (n.videoPath.length > 0) {
      h += 120;
    }
    h += n.text.length > 0 ? Math.min(58, Math.ceil(n.text.length / 14) * 20) : 0;
    h += 30;
    return h;
  }

  private dateText(n: NoteItem): string {
    const d: Date = new Date(n.time);
    return `${d.getMonth() + 1}月${d.getDate()}日`;
  }

  @Builder
  NoteCard(n: NoteItem) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (n.mediaPaths.length > 0) {
          Image(`file://${n.mediaPaths[0]}`)
            .width('100%')
            .aspectRatio(n.coverW / n.coverH)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
        } else if (n.videoPath.length > 0) {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.play_fill')).fontSize(26).fontColor([$r('app.color.text_secondary')])
          }
          .width('100%')
          .aspectRatio(n.coverW / n.coverH)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(12)
          Text('视频')
            .fontSize(9).fontColor(Color.White)
            .backgroundColor('#99000000')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .margin({ top: 8, right: 8 })
        }
      }
      .width('100%')

      if (n.text.length > 0) {
        Text(n.text)
          .fontSize(13).lineHeight(19).fontColor($r('app.color.text_primary'))
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      Row({ space: 10 }) {
        Text(this.dateText(n))
          .fontSize(10).fontColor($r('app.color.text_tertiary'))
        Blank()
        // 本地点赞 / 评论数
        Row({ space: 3 }) {
          SymbolGlyph(n.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(12)
            .fontColor(n.liked ? [$r('app.color.tag_red')] : [$r('app.color.text_tertiary')])
          Text(n.liked ? '1' : '0').fontSize(10).fontColor($r('app.color.text_tertiary'))
        }
        Row({ space: 3 }) {
          SymbolGlyph($r('sys.symbol.message')).fontSize(12).fontColor([$r('app.color.text_tertiary')])
          Text(`${n.comments.length}`).fontSize(10).fontColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .borderRadius(14)
    .backgroundColor($r('app.color.card_background'))
    .onClick((): void => {
      AppStorage.setOrCreate<string>('currentNoteId', n.id);
      router.pushUrl({ url: 'pages/NoteDetail' });
    })
  }

  build() {
    Stack() {
      Scroll(this.pageScroller) {
        Row({ space: 10 }) {
          // 左列
          Column({ space: 10 }) {
            Column().width('100%').height(topAvoid(this.statusBarHeight) + 12)
            ForEach(this.leftCol, (n: NoteItem): void => {
              this.NoteCard(n)
            }, (n: NoteItem): string => `${n.id}_${this.notesRev}`)
            Column().width('100%').height(SPACER_H)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 右列
          Column({ space: 10 }) {
            Column().width('100%').height(topAvoid(this.statusBarHeight) + 12)
            ForEach(this.rightCol, (n: NoteItem): void => {
              this.NoteCard(n)
            }, (n: NoteItem): string => `${n.id}_${this.notesRev}`)
            Column().width('100%').height(SPACER_H)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Top)
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)

      // 空态
      if (this.notes.length === 0) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(34).fontColor([$r('app.color.text_tertiary')])
          Text('还没有笔记').fontSize(16).fontColor($r('app.color.text_secondary'))
          Text('点右上角「+」，把做菜的点滴记录下来').fontSize(13).fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .padding({ top: 160 })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
  }
}
