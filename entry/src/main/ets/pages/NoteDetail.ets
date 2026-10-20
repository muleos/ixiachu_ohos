/** 笔记详情（v1.12.1）：多图左右滑动（Swiper）+ 本地点赞 + 本地评论，右上角删除 */
import { router, promptAction } from '@kit.ArkUI';
import { NoteComment, NoteItem } from '../model/Models';
import { NoteStore } from '../service/NoteStore';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct NoteDetail {
  private scroller: Scroller = new Scroller();
  @StorageProp('notesRev') notesRev: number = 0;
  @State commentInput: string = '';

  private note(): NoteItem {
    const id: string = AppStorage.get<string>('currentNoteId') ?? '';
    const n: NoteItem | null = NoteStore.get(id);
    return n !== null ? n : new NoteItem();
  }

  private dateText(n: NoteItem): string {
    const d: Date = new Date(n.time);
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
  }

  private sendComment(): void {
    const id: string = AppStorage.get<string>('currentNoteId') ?? '';
    if (this.commentInput.trim().length === 0) {
      return;
    }
    NoteStore.addComment(id, this.commentInput);
    this.commentInput = '';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      FrostPage({
        title: '笔记详情',
        scroller: this.scroller,
        rightIcon: $r('sys.symbol.trash'),
        rightIconColor: $r('app.color.tag_red'),
        onRight: (): void => {
          promptAction.showDialog({
            title: '删除笔记',
            message: '删除后不可恢复，确定删除？',
            buttons: [
              { text: '取消', color: '#666666' },
              { text: '删除', color: '#F8284C' }
            ]
          }).then((result: promptAction.ShowDialogSuccessResponse): void => {
            if (result.index === 1) {
              NoteStore.remove(AppStorage.get<string>('currentNoteId') ?? '');
              router.back();
            }
          });
        }
      }) {
        Column({ space: 14 }) {
          Text(`${this.dateText(this.note())} · ${this.note().source}`)
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')

          if (this.note().text.length > 0) {
            Text(this.note().text)
              .fontSize(15).lineHeight(24).fontColor($r('app.color.text_primary'))
              .width('100%')
          }

          // 多图左右滑动（小红书同款交互）
          if (this.note().mediaPaths.length > 0) {
            Stack({ alignContent: Alignment.TopEnd }) {
              Swiper() {
                ForEach(this.note().mediaPaths, (p: string): void => {
                  Image(`file://${p}`)
                    .width('100%')
                    .aspectRatio(this.note().coverW / this.note().coverH)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(14)
                    .backgroundColor($r('app.color.card_background'))
                }, (p: string): string => p)
              }
              .index(0)
              .indicator(true)
              .loop(false)
              .borderRadius(14)
              if (this.note().mediaPaths.length > 1) {
                Text(`${this.note().mediaPaths.length} 图`)
                  .fontSize(10).fontColor(Color.White)
                  .backgroundColor('#99000000')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(9)
                  .margin({ top: 10, right: 10 })
              }
            }
            .width('100%')
          }

          if (this.note().videoPath.length > 0) {
            Video({
              src: `file://${this.note().videoPath}`,
              previewUri: undefined,
              controller: new VideoController()
            })
              .width('100%')
              .height(220)
              .borderRadius(14)
              .autoPlay(false)
              .controls(true)
              .backgroundColor($r('app.color.card_background'))
          }

          // 点赞行
          Row({ space: 18 }) {
            Row({ space: 5 }) {
              SymbolGlyph(this.note().liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                .fontSize(19)
                .fontColor(this.note().liked ? [$r('app.color.tag_red')] : [$r('app.color.text_secondary')])
              Text(this.note().liked ? '已赞' : '点赞')
                .fontSize(13)
                .fontColor(this.note().liked ? $r('app.color.tag_red') : $r('app.color.text_secondary'))
            }
            .onClick((): void => {
              NoteStore.toggleLike(AppStorage.get<string>('currentNoteId') ?? '');
            })

            Row({ space: 5 }) {
              SymbolGlyph($r('sys.symbol.message')).fontSize(17).fontColor([$r('app.color.text_secondary')])
              Text(`评论 ${this.note().comments.length}`)
                .fontSize(13).fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          .padding(12)
          .borderRadius(14)
          .backgroundColor($r('app.color.card_background'))

          // 评论区
          Text(`评论（${this.note().comments.length}）`)
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            .width('100%')

          if (this.note().comments.length === 0) {
            Text('还没有评论，写下第一条吧')
              .fontSize(12).fontColor($r('app.color.text_tertiary')).width('100%')
          }

          Column({ space: 8 }) {
            ForEach(this.note().comments, (c: NoteComment): void => {
              Row({ space: 8 }) {
                Text(`${new Date(c.time).getMonth() + 1}月${new Date(c.time).getDate()}日`)
                  .fontSize(10).fontColor($r('app.color.text_tertiary'))
                Text(c.text).fontSize(13).fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
              }
              .width('100%')
              .padding(10)
              .borderRadius(10)
              .backgroundColor($r('app.color.card_background'))
            }, (c: NoteComment): string => `${c.id}_${this.notesRev}`)
          }
          .width('100%')

          Column().width('100%').height(76)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }

      // 底部评论输入条（悬浮，键盘 RESIZE 模式下自动上移）
      Row({ space: 10 }) {
        TextInput({ placeholder: '说点什么…', text: this.commentInput })
          .layoutWeight(1)
          .height(40).fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(20)
          .onChange((v: string): void => {
            this.commentInput = v;
          })
          .onSubmit((): void => {
            this.sendComment();
          })
        Button('发送')
          .height(40).borderRadius(20)
          .padding({ left: 18, right: 18 })
          .backgroundColor($r('app.color.accent'))
          .fontColor(Color.White)
          .fontSize(14)
          .onClick((): void => {
            this.sendComment();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 12 })
      .backgroundColor($r('app.color.page_background'))
      .border({ width: { top: 0.5 }, color: $r('app.color.divider') })
    }
    .width('100%')
    .height('100%')
  }
}
