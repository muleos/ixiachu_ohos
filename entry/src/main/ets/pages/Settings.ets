/**
 * 设置 —— 临期提醒 / 天气城市（支持实时定位）/ 本地价数据维护 / 关于。
 * v1.9.0：整体切换官方 HdsNavigation 沉浸光感（VHome FrostScaffold 同款）——
 * MINI 顶栏 + IMMERSIVE_GRADIENT_BLUR 滚动渐变模糊，内容首项 spacer 避让随滚动透出。
 */
import { router, promptAction } from '@kit.ArkUI';
import { common, bundleManager } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import {
  HdsNavigation, HdsNavigationTitleMode, DividerShowType
} from '@kit.UIDesignKit';
import { DataStore } from '../service/DataStore';
import { Notify } from '../service/Notify';
import { Weather, City } from '../service/Weather';
import { LocationService, LocateResult } from '../service/LocationService';
import { frostTitleStyle, topAvoid, queryStatusBarHeight } from '../utils/Theme';

@Entry
@Component
struct Settings {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  /** 页面挂载时直查窗口避让区（广播滞后/失败时的自查兜底，v1.2.2 同款） */
  @State queriedBar: number = 0;
  /** 主滚动容器（官方光感滚动源绑定） */
  private scroller: Scroller = new Scroller();
  @State notifyOn: boolean = Notify.enabled();
  @State localPriceCount: number = DataStore.localPriceCount();
  @State showCity: boolean = false;
  /** 天气城市展示（含来源角标，定位/手选后刷新） */
  @State cityText: string = Weather.cityLabel();
  /** 定位进行中（按钮防重入） */
  @State locating: boolean = false;
  /** 版本号（异步取自包信息） */
  @State versionName: string = '';

  aboutToAppear(): void {
    this.loadVersion();
    queryStatusBarHeight(getContext(this)).then((h: number): void => {
      if (h > 0) {
        this.queriedBar = h;
      }
    });
  }

  /** 状态栏高度：广播/窗口直查取大者，36vp 兜底 */
  private topInset(): number {
    return Math.max(Math.max(this.statusBarHeight, this.queriedBar), 36);
  }

  private loadVersion(): void {
    try {
      const info: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.versionName = `v${info.versionName}`;
    } catch (e) {
    }
  }

  build() {
    Stack() {
      HdsNavigation() {
        Scroll(this.scroller) {
          Column({ space: 14 }) {
            // 首项避让 spacer：显式高度（空容器 padding 在部分管线会被折叠），
            // 随内容滚走，内容透出到标题栏后面（光感采样）
            Column().width('100%').height(topAvoid(this.topInset()) + 12)

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

            // 天气城市（支持实时定位）
            Column({ space: 4 }) {
              Row({ space: 10 }) {
                Text('天气城市').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.cityText} ›`).fontSize(13).fontColor($r('app.color.text_secondary'))
                  .onClick((): void => {
                    this.showCity = true;
                  })
                Button(this.locating ? '定位中…' : '定位')
                  .fontSize(12).height(28).borderRadius(14)
                  .backgroundColor($r('app.color.accent_soft'))
                  .fontColor($r('app.color.accent'))
                  .enabled(!this.locating)
                  .margin({ left: 8 })
                  .onClick((): void => {
                    this.doLocate();
                  })
              }
              .width('100%')
              Text('按实时气温修正新鲜度与时令推荐（Open-Meteo，缓存 6 小时）；定位坐标仅本地使用，不上传')
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

            // 隐私政策
            Row({ space: 10 }) {
              Text('隐私政策').fontSize(15).fontColor($r('app.color.text_primary'))
              Blank()
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(14).fontColor([$r('app.color.text_tertiary')])
            }
            .width('100%').padding(16).borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .onClick((): void => {
              router.pushUrl({ url: 'pages/Privacy' });
            })

            // 关于
            Column({ space: 4 }) {
              Row({ space: 10 }) {
                Text('I下厨').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Blank()
                Text(this.versionName).fontSize(13).fontColor($r('app.color.text_tertiary'))
              }
              .width('100%')
              Text('菜谱管理 · 点菜推荐 · 采购清单 · 食材管理 · 桌面卡片')
                .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
            }
            .width('100%').padding(16).borderRadius(16)
            .backgroundColor($r('app.color.card_background'))

            // 尾部留白：避让小白条手势区（底部沉浸直达屏幕底）
            Column().height(56).width('100%')
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 20 })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .align(Alignment.Top)
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: { mainTitle: '设置' },
          divider: { showType: DividerShowType.OFF }
        },
        style: frostTitleStyle()
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(false)
      .bindToScrollable([this.scroller])
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 城市选择弹层（手选即退出定位模式）
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
                  this.cityText = Weather.cityLabel();
                  this.showCity = false;
                })
            }, (c: string): string => c)
          }
          .width('100%')
        }
        .padding(20)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_background'))
        // Stack 下 width('100%') 会让 margin 溢出失效（卡片几乎全宽），
        // 改 calc 显式收窄：左右各 24vp
        .width('calc(100% - 48vp)')
        .onClick((): void => {
          // 阻断冒泡，避免点弹窗内容关闭
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 实时定位 → 就近匹配城市 → 切定位模式（坐标只存本地，气温按坐标直取） */
  private async doLocate(): Promise<void> {
    this.locating = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const r: LocateResult = await LocationService.locate(ctx);
      if (r.ok) {
        const near: City = Weather.nearestCity(r.lat, r.lon);
        Weather.setAuto(near.name, r.lat, r.lon);
        this.cityText = Weather.cityLabel();
        promptAction.showToast({ message: `已定位：${near.name}，气温修正将按实时位置更新` });
      } else {
        promptAction.showToast({ message: r.message });
      }
    } catch (e) {
      promptAction.showToast({ message: '定位失败，请稍后重试或手选城市' });
    }
    this.locating = false;
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
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        DataStore.clearLocalPrices();
        this.localPriceCount = 0;
        promptAction.showToast({ message: '已清空本地价数据' });
      }
    });
  }
}
