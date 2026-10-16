/** 设置 —— 临期提醒开关 / 天气城市 / 本地价数据维护 / 关于 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { DataStore } from '../service/DataStore';
import { Notify } from '../service/Notify';
import { Weather } from '../service/Weather';
import { queryStatusBarHeight } from '../utils/Theme';

@Entry
@Component
struct Settings {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @State queriedBar: number = 0;
  @State notifyOn: boolean = Notify.enabled();
  @State localPriceCount: number = DataStore.localPriceCount();
  @State showCity: boolean = false;

  aboutToAppear(): void {
    queryStatusBarHeight(getContext(this)).then((h: number): void => {
      if (h > 0) {
        this.queriedBar = h;
      }
    });
  }

  build() {
    Stack() {
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.text_primary')])
            .onClick((): void => {
              router.back();
            })
          Text('设置')
            .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            .margin({ left: 8 })
          Blank()
        }
        .width('100%')
        .constraintSize({ minHeight: 44 })
        .padding({ left: 12, right: 20, top: Math.max(Math.max(this.statusBarHeight, this.queriedBar), 36) })

        Scroll() {
          Column({ space: 14 }) {
            // 临期提醒
            Column({ space: 4 }) {
              Row({ space: 10 }) {
                Text('临期提醒').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.notifyOn })
                  .selectedColor($r('app.color.accent'))
                  .onChange((on: boolean): void => {
                    this.applyNotify(on);
                  })
              }
              .width('100%')
              Text('启动时检查临期食材，每天最多提醒一次')
                .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
            }
            .width('100%').padding(16).borderRadius(16)
            .backgroundColor($r('app.color.card_background'))

            // 天气城市
            Column({ space: 4 }) {
              Row({ space: 10 }) {
                Text('天气城市').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${Weather.currentCity()} ›`).fontSize(13).fontColor($r('app.color.text_secondary'))
                  .onClick((): void => {
                    this.showCity = true;
                  })
              }
              .width('100%')
              Text('按实时气温修正新鲜度估算（Open-Meteo，缓存 6 小时）')
                .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
            }
            .width('100%').padding(16).borderRadius(16)
            .backgroundColor($r('app.color.card_background'))

            // 数据维护
            Column({ space: 4 }) {
              Row({ space: 10 }) {
                Text('本地小票菜价').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.localPriceCount} 项`).fontSize(13).fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              Text('小票识别积累的真实价（采购清单优先使用）')
                .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
              Button('清空本地价数据')
                .width('100%').height(36).borderRadius(18).margin({ top: 6 })
                .backgroundColor($r('app.color.page_background'))
                .fontColor($r('app.color.tag_red'))
                .onClick((): void => {
                  this.confirmClearPrices();
                })
            }
            .width('100%').padding(16).borderRadius(16)
            .backgroundColor($r('app.color.card_background'))

            // 关于
            Column({ space: 4 }) {
              Row({ space: 10 }) {
                Text('I下厨').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Blank()
                Text('v1.6.0').fontSize(13).fontColor($r('app.color.text_tertiary'))
              }
              .width('100%')
              Text('菜谱管理 · 点菜推荐 · 采购清单 · 食材管理')
                .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
            }
            .width('100%').padding(16).borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 12, bottom: 40 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      // 城市选择弹层（与食材管理页同款）
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
  }

  /** 开提醒：先补授权；关提醒：直接落开关 */
  private async applyNotify(on: boolean): Promise<void> {
    if (!on) {
      this.notifyOn = false;
      Notify.setEnabled(false);
      return;
    }
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(ctx);
      }
      this.notifyOn = true;
      Notify.setEnabled(true);
    } catch (e) {
      // 拒绝授权：开关弹回关闭并提示
      this.notifyOn = false;
      Notify.setEnabled(false);
      promptAction.showToast({ message: '未获得通知权限，可在系统设置中手动开启' });
    }
  }

  private confirmClearPrices(): void {
    promptAction.showDialog({
      title: '清空本地小票菜价？',
      message: '采购清单将回退为云端价/内置基准价，重新扫描小票即可积累。此操作不可撤销。',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '清空', color: '#F8284C' }
      ]
    }).then((idx: number) => {
      if (idx === 1) {
        DataStore.clearLocalPrices();
        this.localPriceCount = 0;
        promptAction.showToast({ message: '已清空本地价数据' });
      }
    });
  }
}
