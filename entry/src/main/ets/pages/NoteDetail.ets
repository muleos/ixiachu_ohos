/** 笔记详情（v1.12.0）：全文 + 图片纵向浏览 + 视频播放，右上角删除 */
import { router, promptAction } from '@kit.ArkUI';
import { NoteItem } from '../model/Models';
import { NoteStore } from '../service/NoteStore';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct NoteDetail {
  private scroller: Scroller = new Scroller();

  private note(): NoteItem {
    const id: string = AppStorage.get<string>('currentNoteId') ?? '';
    const n: NoteItem | null = NoteStore.get(id);
    return n !== null ? n : new NoteItem();
  }

  private dateText(n: NoteItem): string {
    const d: Date = new Date(n.time);
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
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
          Text(this.dateText(this.note()))
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')

          if (this.note().text.length > 0) {
            Text(this.note().text)
              .fontSize(15).lineHeight(24).fontColor($r('app.color.text_primary'))
              .width('100%')
          }

          ForEach(this.note().mediaPaths, (p: string): void => {
            Image(`file://${p}`)
              .width('100%')
              .borderRadius(14)
              .backgroundColor($r('app.color.card_background'))
          }, (p: string): string => p)

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

          if (this.note().text.length === 0 && this.note().mediaPaths.length === 0
            && this.note().videoPath.length === 0) {
            Text('笔记不存在或已删除')
              .fontSize(13).fontColor($r('app.color.text_tertiary')).width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 40 })
          }

          Column().width('100%').height(20)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
    }
  }
}
