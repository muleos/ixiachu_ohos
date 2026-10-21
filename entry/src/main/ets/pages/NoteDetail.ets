/** 笔记详情（v1.12.2）：多图左右滑动 + 本地点赞 + 评论（@State 实时刷新，输入框随内容流） */
import { router, promptAction } from '@kit.ArkUI';
import { NoteComment, NoteItem } from '../model/Models';
import { NoteStore } from '../service/NoteStore';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct NoteDetail {
  private scroller: Scroller = new Scroller();
  @StorageProp('notesRev') @Watch('onNotesRev') notesRev: number = 0;
  /** 详情数据镜像：notesRev 变化即重载，评论/点赞实时刷新 */
  @State noteData: NoteItem = new NoteItem();
  @State commentInput: string = '';
  /** 评论输入框默认隐藏，点评论按钮展示（小红书同款） */
  @State showInput: boolean = false;

  aboutToAppear(): void {
    this.loadNote();
  }

  onNotesRev(): void {
    this.loadNote();
  }

  private loadNote(): void {
    const id: string = AppStorage.get<string>('currentNoteId') ?? '';
    const n: NoteItem | null = NoteStore.get(id);
    this.noteData = n !== null ? n : new NoteItem();
  }

  private dateText(t: number): string {
    const d: Date = new Date(t);
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
  }

  /** 评论时间：精确到秒 */
  private commentTime(t: number): string {
    const d: Date = new Date(t);
    const p = (v: number): string => v < 10 ? `0${v}` : `${v}`;
    return `${d.getMonth() + 1}月${d.getDate()}日 ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
  }

  private sendComment(): void {
    if (this.commentInput.trim().length === 0) {
      return;
    }
    NoteStore.addComment(AppStorage.get<string>('currentNoteId') ?? '', this.commentInput);
    this.commentInput = '';
    // 新评论可见：滚到内容底
    this.scroller.scrollEdge(Edge.Bottom);
  }

  build() {
    Stack() {
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
          Text(`${this.dateText(this.noteData.time)} · ${this.noteData.source}`)
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')

          if (this.noteData.text.length > 0) {
            Text(this.noteData.text)
              .fontSize(15).lineHeight(24).fontColor($r('app.color.text_primary'))
              .width('100%')
          }

          // 多图左右滑动（小红书同款交互）
          if (this.noteData.mediaPaths.length > 0) {
            Stack({ alignContent: Alignment.TopEnd }) {
              Swiper() {
                ForEach(this.noteData.mediaPaths, (p: string): void => {
                  Image(`file://${p}`)
                    .width('100%')
                    .aspectRatio(this.noteData.coverW / this.noteData.coverH)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(14)
                    .backgroundColor($r('app.color.card_background'))
                }, (p: string): string => p)
              }
              .index(0)
              .indicator(true)
              .loop(false)
              .borderRadius(14)
              if (this.noteData.mediaPaths.length > 1) {
                Text(`${this.noteData.mediaPaths.length} 图`)
                  .fontSize(10).fontColor(Color.White)
                  .backgroundColor('#99000000')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(9)
                  .margin({ top: 10, right: 10 })
              }
            }
            .width('100%')
          }

          if (this.noteData.videoPath.length > 0) {
            Video({
              src: `file://${this.noteData.videoPath}`,
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
              SymbolGlyph(this.noteData.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                .fontSize(19)
                .fontColor(this.noteData.liked ? [$r('app.color.tag_red')] : [$r('app.color.text_secondary')])
              Text(this.noteData.liked ? '已赞' : '点赞')
                .fontSize(13)
                .fontColor(this.noteData.liked ? $r('app.color.tag_red') : $r('app.color.text_secondary'))
            }
            .onClick((): void => {
              NoteStore.toggleLike(AppStorage.get<string>('currentNoteId') ?? '');
            })

            Row({ space: 5 }) {
              SymbolGlyph($r('sys.symbol.message')).fontSize(17).fontColor([$r('app.color.text_secondary')])
              Text(`评论 ${this.noteData.comments.length}`)
                .fontSize(13).fontColor($r('app.color.text_secondary'))
            }
            .onClick((): void => {
              // 小红书同款：点评论按钮展开输入框并定位到评论区
              this.showInput = !this.showInput;
              if (this.showInput) {
                this.scroller.scrollEdge(Edge.Bottom);
              }
            })
          }
          .width('100%')
          .padding(12)
          .borderRadius(14)
          .backgroundColor($r('app.color.card_background'))

          // 评论区
          Text(`评论（${this.noteData.comments.length}）`)
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            .width('100%')

          if (this.noteData.comments.length === 0) {
            Text('还没有评论，写下第一条吧')
              .fontSize(12).fontColor($r('app.color.text_tertiary')).width('100%')
          }

          Column({ space: 8 }) {
            ForEach(this.noteData.comments, (c: NoteComment): void => {
              Column({ space: 4 }) {
                Row() {
                  Text(this.commentTime(c.time)).fontSize(10).fontColor($r('app.color.text_tertiary'))
                  Blank()
                  // 自己发布的评论：删除按钮
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(13)
                    .fontColor([$r('app.color.text_tertiary')])
                    .onClick((): void => {
                      NoteStore.removeComment(AppStorage.get<string>('currentNoteId') ?? '', c.id);
                    })
                }
                .width('100%')
                Text(c.text).fontSize(13).fontColor($r('app.color.text_primary')).width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(10)
              .borderRadius(10)
              .backgroundColor($r('app.color.page_background'))
            }, (c: NoteComment): string => `${c.id}_${c.time}`)
          }
          .width('100%')

          // 评论输入（默认隐藏，点评论按钮展开；随内容流不顶飞页面）
          if (this.showInput) {
            Column() {
              Row({ space: 10 }) {
                TextInput({ placeholder: '说点什么…', text: this.commentInput })
                  .layoutWeight(1)
                  .height(40).fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .backgroundColor($r('app.color.page_background'))
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
            }
            .width('100%')
            .padding(12)
            .borderRadius(14)
            .backgroundColor($r('app.color.card_background'))
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
