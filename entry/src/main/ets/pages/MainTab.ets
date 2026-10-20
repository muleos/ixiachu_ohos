/**
 * I下厨 主框架（v1.10.2）：
 * 顶栏：HdsNavigation 沉浸光感渐变模糊（IMMERSIVE_GRADIENT_BLUR，bindToScrollable 绑定各页滚动器）。
 * 底栏：VHome 同款自建悬浮玻璃 dock（真模糊 BlurStyle.Regular + 白/墨蓝玻璃底 + 描边投影），
 *       内容延伸到 dock 后面穿透采样——官方 HdsTabs 悬浮岛材质真机偏实底，沉浸感不足，故换回自绘。
 * 避让：四 Tab 列表底部留白 132vp（dock 占位 24 + 56 = 80vp 之上留足余量）。
 */
import { mediaquery, router } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, DividerShowType } from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { accentColor, frostTitleStyle } from '../utils/Theme';
import { DataStore } from '../service/DataStore';
import { MenuLibraryTab } from './tabs/MenuLibraryTab';
import { InspirationTab } from './tabs/InspirationTab';
import { OrderTab } from './tabs/OrderTab';
import { ShoppingTab } from './tabs/ShoppingTab';
import { PantryTab } from './tabs/PantryTab';

/** 玻璃 dock 几何（VHome dockFrost 同款） */
const DOCK_HEIGHT: number = 56;
const DOCK_BOTTOM_MARGIN: number = 24;

class TabDef {
  index: number = 0;
  label: string = '';
  icon: Resource = $r('sys.symbol.doc_text');

  constructor(index: number, label: string, icon: Resource) {
    this.index = index;
    this.label = label;
    this.icon = icon;
  }
}

const TABS: TabDef[] = [
  new TabDef(0, '菜单库', $r('sys.symbol.doc_text')),
  new TabDef(1, '灵感', $r('sys.symbol.lightbulb')),
  new TabDef(2, '点菜', $r('sys.symbol.list_bullet_square')),
  new TabDef(3, '采购', $r('sys.symbol.bag')),
  new TabDef(4, '食材', $r('sys.symbol.folder'))
];

@Entry
@Component
struct MainTab {
  @StorageProp('isDarkMode') isDark: boolean = false;
  /** 通知点击透传的目标 Tab（launchTab>=0 时切换；onNewWant 热启动也会触发本 Watch） */
  @StorageProp('launchTab') @Watch('onLaunchTab') launchTab: number = -1;
  @State activeTab: number = 0;
  /** dock 按压态（UX 规范：按下变淡） */
  @State pressedIndex: number = -1;
  /** 首启隐私同意（AGC 审核 4.1：未同意前遮罩阻断使用） */
  @State showPrivacy: boolean = DataStore.getSetting('privacy_agreed') !== '1';
  private tabsController: TabsController = new TabsController();
  private libraryScroller: Scroller = new Scroller();
  private inspirationScroller: Scroller = new Scroller();
  private orderScroller: Scroller = new Scroller();
  private shoppingScroller: Scroller = new Scroller();
  private pantryScroller: Scroller = new Scroller();
  private mqListener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    // 冷启动通知透传：直接落在目标 Tab
    const tab: number = AppStorage.get<number>('launchTab') ?? -1;
    if (tab >= 0) {
      this.activeTab = tab;
    }
    // 深浅色监听：初始化 isDarkMode（冷启动即处于深色时也能正确置位）
    try {
      this.mqListener = this.getUIContext().getMediaQuery().matchMediaSync('(dark-mode: true)');
      AppStorage.setOrCreate<boolean>('isDarkMode', this.mqListener.matches as boolean);
      this.mqListener.on('change', (res: mediaquery.MediaQueryResult): void => {
        AppStorage.setOrCreate<boolean>('isDarkMode', res.matches as boolean);
      });
    } catch (e) {
    }
  }

  aboutToDisappear(): void {
    if (this.mqListener !== null) {
      try {
        (this.mqListener as mediaquery.MediaQueryListener).off('change');
      } catch (e) {
      }
    }
  }

  /** 热启动点通知：AppStorage.launchTab 变化 → 切页 */
  onLaunchTab(): void {
    if (this.launchTab >= 0) {
      this.activeTab = this.launchTab;
      AppStorage.setOrCreate<number>('launchTab', -1);
    }
  }

  private currentTitle(): string {
    if (this.activeTab === 1) {
      return '灵感';
    }
    if (this.activeTab === 2) {
      return '点菜';
    }
    if (this.activeTab === 3) {
      return '采购清单';
    }
    if (this.activeTab === 4) {
      return '食材管理';
    }
    return '菜单库';
  }

  @Builder
  dockItems() {
    ForEach(TABS, (t: TabDef): void => {
      Column({ space: 2 }) {
        SymbolGlyph(t.icon)
          .fontSize(21)
          .fontColor([this.activeTab === t.index ? accentColor() : $r('app.color.text_secondary')])
          .opacity(this.pressedIndex === t.index ? 0.55 : 1)
        Text(t.label)
          .fontSize(10)
          .fontWeight(this.activeTab === t.index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeTab === t.index ? accentColor() : $r('app.color.text_secondary'))
          .opacity(this.pressedIndex === t.index ? 0.55 : 1)
      }
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .onClick((): void => {
        this.tabsController.changeIndex(t.index);
        this.activeTab = t.index;
      })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) {
          this.pressedIndex = t.index;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedIndex = -1;
        }
      })
      .accessibilityText(t.label + (this.activeTab === t.index ? '，已选中' : ''))
      .accessibilityLevel('yes')
    }, (t: TabDef): string => `dock${t.index}_${this.activeTab}`)
  }

  /** 磨砂玻璃 dock（VHome dockFrost 同款：白/墨蓝玻璃底 + 真模糊 + 描边 + 投影），
   *  内容延伸到 dock 后面穿透采样，沉浸光感真实可见 */
  @Builder
  dockFrost() {
    Column() {
      Row() {
        this.dockItems()
      }
      .width('100%')
      .height(DOCK_HEIGHT)
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 20, right: 20 })
      .borderRadius(DOCK_HEIGHT / 2)
      .backgroundColor(this.isDark ? '#661B1E24' : '#66FFFFFF')
      .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
      .border({ width: 0.5, color: this.isDark ? '#55FFFFFF' : '#B8FFFFFF' })
      .clip(true)
      .shadow({ radius: 24, color: this.isDark ? '#88000000' : '#30101824', offsetY: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: DOCK_BOTTOM_MARGIN })
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack() {
    HdsNavigation() {
      Tabs({ barPosition: BarPosition.End, index: this.activeTab, controller: this.tabsController }) {
        TabContent() {
          MenuLibraryTab({ pageScroller: this.libraryScroller })
        }

        TabContent() {
          InspirationTab({ pageScroller: this.inspirationScroller })
        }

        TabContent() {
          OrderTab({ pageScroller: this.orderScroller })
        }

        TabContent() {
          ShoppingTab({ pageScroller: this.shoppingScroller })
        }

        TabContent() {
          PantryTab({ pageScroller: this.pantryScroller })
        }
      }
      .width('100%')
      .height('100%')
      .barPosition(BarPosition.End)
      .barHeight(0)
      .scrollable(false)
      .animationDuration(0)
      .backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onChange((index: number): void => {
        this.activeTab = index;
      })
    }
    .titleBar({
      style: frostTitleStyle(),
      avoidLayoutSafeArea: true,
      content: {
        title: {
          mainTitle: this.currentTitle()
        },
        divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideTitleBar(false)
    .hideBackButton(true)
    .bindToScrollable([this.libraryScroller, this.inspirationScroller, this.orderScroller, this.shoppingScroller, this.pantryScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

    // 悬浮玻璃 dock（叠在 Tabs 之上；外层 hitTest None，点击落在页签项）
    this.dockFrost()

    // 首启隐私同意弹层（审核 4.1）：同意前阻断使用；可看全文；不同意退出
    if (this.showPrivacy) {
      Column() {
        Column({ space: 14 }) {
          Text('用户协议与隐私政策').fontSize(17).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Scroll() {
            Text('欢迎使用 I下厨。在开始使用前，请阅读并了解《隐私政策》：\n\n· 本应用不注册、不登录，不收集任何身份信息；\n· 菜谱、库存、采购清单等数据仅保存在您的设备本地；\n· 联网仅用于获取云端菜价参考与当地气温（只读请求，不含个人信息）；\n· 仅在您主动点击「定位」时读取一次位置，用于就近匹配城市，坐标不上传；\n· 小票照片仅在本机识别，不上传；\n· 无广告、无第三方追踪。')
              .fontSize(13).lineHeight(21)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .constraintSize({ maxHeight: 220 })
          .scrollBar(BarState.Auto)
          Text('点击「同意并继续」即表示您已阅读并同意上述内容与完整《隐私政策》。')
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
          Text('查看完整《隐私政策》')
            .fontSize(13).fontColor($r('app.color.accent'))
            .width('100%')
            .onClick((): void => {
              router.pushUrl({ url: 'pages/Privacy' });
            })
          Row({ space: 10 }) {
            Button('不同意并退出').fontSize(14).height(40).borderRadius(20).layoutWeight(1)
              .backgroundColor($r('app.color.page_background'))
              .fontColor($r('app.color.text_secondary'))
              .onClick((): void => {
                (getContext(this) as common.UIAbilityContext).terminateSelf();
              })
            Button('同意并继续').fontSize(14).height(40).borderRadius(20).layoutWeight(1)
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .onClick((): void => {
                DataStore.setSetting('privacy_agreed', '1');
                this.showPrivacy = false;
              })
          }
          .width('100%')
        }
        .padding(20)
        .margin({ left: 24, right: 24 })
        .borderRadius(20)
        .backgroundColor($r('app.color.card_background'))
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.5)')
      .justifyContent(FlexAlign.Center)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    }
    .width('100%')
    .height('100%')
  }
}
