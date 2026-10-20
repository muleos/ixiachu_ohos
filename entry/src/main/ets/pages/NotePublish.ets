/**
 * 发布笔记（v1.12.0）：文字 + 图片（最多 9 张）/ 视频（单条），全部拷贝到本地
 * filesDir/notes/ 保存；右上角官方 ✓ 或底部「发布」均可提交。
 */
import { router, promptAction } from '@kit.ArkUI';
import { picker, fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { NoteItem } from '../model/Models';
import { NoteStore } from '../service/NoteStore';
import { FrostPage } from '../components/FrostPage';

const MAX_PHOTOS: number = 9;

@Entry
@Component
struct NotePublish {
  private scroller: Scroller = new Scroller();
  @State text: string = '';
  @State mediaPaths: string[] = [];
  @State videoPath: string = '';
  @State coverW: number = 4;
  @State coverH: number = 3;
  @State publishing: boolean = false;

  private notesDir(ctx: common.UIAbilityContext): string {
    const dir: string = `${ctx.filesDir}/notes`;
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
    } catch (e) {
    }
    return dir;
  }

  /** 选图片（差量补齐到 9 张），首图决定瀑布流比例 */
  private addPhotos(): void {
    const remain: number = MAX_PHOTOS - this.mediaPaths.length;
    if (remain <= 0) {
      promptAction.showToast({ message: `最多 ${MAX_PHOTOS} 张图片` });
      return;
    }
    const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
    photoPicker.select({
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: remain
    }).then(async (result: picker.PhotoSelectResult): Promise<void> => {
      if (result.photoUris.length === 0) {
        return;
      }
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const dir: string = this.notesDir(ctx);
      for (let i = 0; i < result.photoUris.length; i++) {
        if (this.mediaPaths.length >= MAX_PHOTOS) {
          break;
        }
        const dest: string = `${dir}/img_${Date.now()}_${i}.jpg`;
        try {
          const src: fileIo.File = await fileIo.open(result.photoUris[i], fileIo.OpenMode.READ_ONLY);
          try {
            fileIo.copyFileSync(src.fd, dest);
          } finally {
            fileIo.closeSync(src);
          }
          if (this.mediaPaths.length === 0) {
            await this.readAspect(dest);
          }
          this.mediaPaths = this.mediaPaths.concat([dest]);
        } catch (e) {
          // 单张失败跳过
        }
      }
    });
  }

  /** 读首图宽高（瀑布流卡片比例） */
  private async readAspect(path: string): Promise<void> {
    try {
      const src: image.ImageSource = await image.createImageSource(path);
      const info: image.ImageInfo = await src.getImageInfo();
      await src.release();
      if (info.size.width > 0 && info.size.height > 0) {
        this.coverW = info.size.width;
        this.coverH = info.size.height;
      }
    } catch (e) {
      this.coverW = 4;
      this.coverH = 3;
    }
  }

  /** 选视频（单条，替代图片） */
  private addVideo(): void {
    const videoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
    videoPicker.select({
      MIMEType: picker.PhotoViewMIMETypes.VIDEO_TYPE,
      maxSelectNumber: 1
    }).then(async (result: picker.PhotoSelectResult): Promise<void> => {
      if (result.photoUris.length === 0) {
        return;
      }
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const dest: string = `${this.notesDir(ctx)}/video_${Date.now()}.mp4`;
      try {
        const src: fileIo.File = await fileIo.open(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
        try {
          fileIo.copyFileSync(src.fd, dest);
        } finally {
          fileIo.closeSync(src);
        }
        this.mediaPaths = [];
        this.videoPath = dest;
        this.coverW = 4;
        this.coverH = 3;
      } catch (e) {
        promptAction.showToast({ message: '视频保存失败，请重试' });
      }
    });
  }

  private removeMedia(path: string): void {
    if (path === this.videoPath) {
      this.videoPath = '';
      return;
    }
    this.mediaPaths = this.mediaPaths.filter((p: string): boolean => p !== path);
    if (this.mediaPaths.length > 0) {
      this.readAspect(this.mediaPaths[0]);
    } else {
      this.coverW = 4;
      this.coverH = 3;
    }
  }

  private publish(): void {
    if (this.publishing) {
      return;
    }
    if (this.text.trim().length === 0 && this.mediaPaths.length === 0 && this.videoPath.length === 0) {
      promptAction.showToast({ message: '写点什么或添加图片/视频再发布' });
      return;
    }
    this.publishing = true;
    const n: NoteItem = new NoteItem();
    n.id = `n${Date.now()}`;
    n.text = this.text.trim();
    n.mediaPaths = this.mediaPaths.slice();
    n.videoPath = this.videoPath;
    n.coverW = this.coverW;
    n.coverH = this.coverH;
    n.time = Date.now();
    NoteStore.save(n);
    promptAction.showToast({ message: '笔记已保存' });
    router.back();
  }

  build() {
    Stack() {
      FrostPage({
        title: '发布笔记',
        subtitle: '记录做菜的点滴',
        scroller: this.scroller,
        rightIcon: $r('sys.symbol.checkmark'),
        onRight: (): void => {
          this.publish();
        }
      }) {
        Column({ space: 14 }) {
          // 文字
          TextArea({ placeholder: '记录这道菜的火候、调味、翻车与心得…', text: this.text })
            .width('100%')
            .height(180)
            .padding(14)
            .borderRadius(14)
            .backgroundColor($r('app.color.card_background'))
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .onChange((v: string): void => {
              this.text = v;
            })

          // 已选媒体缩略图
          if (this.mediaPaths.length > 0 || this.videoPath.length > 0) {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.mediaPaths, (p: string): void => {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image(`file://${p}`)
                    .width(96)
                    .height(96)
                    .borderRadius(10)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor($r('app.color.page_background'))
                  SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                    .fontSize(18).fontColor([$r('app.color.text_secondary')])
                    .margin({ top: 4, right: 4 })
                    .onClick((): void => {
                      this.removeMedia(p);
                    })
                }
                .margin({ right: 10, bottom: 10 })
              }, (p: string): string => p)

              if (this.videoPath.length > 0) {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Column({ space: 6 }) {
                    SymbolGlyph($r('sys.symbol.play_fill')).fontSize(22).fontColor([$r('app.color.text_secondary')])
                    Text('视频').fontSize(10).fontColor($r('app.color.text_tertiary'))
                  }
                  .width(96)
                  .height(96)
                  .justifyContent(FlexAlign.Center)
                  .borderRadius(10)
                  .backgroundColor($r('app.color.page_background'))
                  SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                    .fontSize(18).fontColor([$r('app.color.text_secondary')])
                    .margin({ top: 4, right: 4 })
                    .onClick((): void => {
                      this.removeMedia(this.videoPath);
                    })
                }
                .margin({ right: 10, bottom: 10 })
              }
            }
            .width('100%')
          }

          // 添加入口
          Row({ space: 10 }) {
            Button() {
              Row({ space: 6 }) {
                SymbolGlyph($r('sys.symbol.picture')).fontSize(17).fontColor([$r('app.color.accent')])
                Text(`图片 ${this.mediaPaths.length}/${MAX_PHOTOS}`).fontSize(13).fontColor($r('app.color.accent'))
              }
            }
            .height(38).borderRadius(19)
            .padding({ left: 14, right: 14 })
            .backgroundColor($r('app.color.accent_soft'))
            .onClick((): void => {
              this.addPhotos();
            })

            Button() {
              Row({ space: 6 }) {
                SymbolGlyph($r('sys.symbol.play_fill')).fontSize(15).fontColor([$r('app.color.accent')])
                Text(this.videoPath.length > 0 ? '已选视频' : '视频').fontSize(13).fontColor($r('app.color.accent'))
              }
            }
            .height(38).borderRadius(19)
            .padding({ left: 14, right: 14 })
            .backgroundColor($r('app.color.accent_soft'))
            .onClick((): void => {
              this.addVideo();
            })
            Blank()
          }
          .width('100%')

          Text('照片与视频仅保存在本机应用目录，不上传')
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')

          Button('发布笔记')
            .width('100%')
            .height(46).borderRadius(23)
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .fontSize(15).fontWeight(FontWeight.Medium)
            .onClick((): void => {
              this.publish();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
    }
  }
}
