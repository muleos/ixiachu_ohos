/**
 * I下厨 主框架 —— 与 CoolapkPura 同款官方槽位：
 * HdsNavigation 顶栏（沉浸光感渐变模糊）+ HdsTabs 悬浮胶囊底栏（barFloatingStyle）。
 * 底栏：barHeight 56 / barBottomMargin 30 / IMMERSIVE 材质，选中色 = 品牌 accent。
 * 顶栏：IMMERSIVE_GRADIENT_BLUR 滚动光感，bindToScrollable 绑定各页滚动器。
 */
import { SymbolGlyphModifier, mediaquery, router } from '@kit.ArkUI';
import {
  HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController, HdsTabsModifier,
  hdsMaterial, DividerShowType
} from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { accentColor, frostTitleStyle } from '../utils/Theme';
import { DataStore } from '../service/DataStore';
import { MenuLibraryTab } from './tabs/MenuLibraryTab';
import { OrderTab } from './tabs/OrderTab';
import { ShoppingTab } from './tabs/ShoppingTab';
import { PantryTab } from './tabs/PantryTab';

const TAB_BAR_HEIGHT: number = 56;

@Entry
@Component
struct MainTab {
  @StorageProp('isDarkMode') @Watch('onThemeChanged') isDark: boolean = false;
  /** 通知点击透传的目标 Tab（launchTab>=0 时切换；onNewWant 热启动也会触发本 Watch） */
  @StorageProp('launchTab') @Watch('onLaunchTab') launchTab: number = -1;
  @State activeTab: number = 0;
  /** 首启隐私同意（AGC 审核 4.1：未同意前遮罩阻断使用） */
  @State showPrivacy: boolean = DataStore.getSetting('privacy_agreed') !== '1';
  @State hdsTabsModifier: HdsTabsModifier = new HdsTabsModifier();
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  private libraryScroller: Scroller = new Scroller();
  private orderScroller: Scroller = new Scroller();
  private shoppingScroller: Scroller = new Scroller();
  private pantryScroller: Scroller = new Scroller();
  private mqListener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    this.configureHdsTabs();
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

  /** 深浅色切换：modifier 持有颜色，必须整体换新 */
  private onThemeChanged(): void {
    this.configureHdsTabs();
  }

  private configureHdsTabs(): void {
    const modifier: HdsTabsModifier = new HdsTabsModifier();
    modifier
      .vertical(false)
      .barPosition(BarPosition.End)
      .barHeight(TAB_BAR_HEIGHT)
      .barFloatingStyle({
        adaptToHandedness: true,
        barBottomMargin: 30,
        lightColor: accentColor(),
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      });
    this.hdsTabsModifier = modifier;
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
      return '点菜';
    }
    if (this.activeTab === 2) {
      return '采购清单';
    }
    if (this.activeTab === 3) {
      return '食材管理';
    }
    return '菜单库';
  }

  private hdsTabBar(icon: Resource, label: string): BottomTabBarStyle {
    const normalGlyph: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE);
    normalGlyph.fontColor([$r('app.color.text_secondary')]);
    const selectedGlyph: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE);
    selectedGlyph.fontColor([accentColor()]);
    return BottomTabBarStyle.of({ normal: normalGlyph, selected: selectedGlyph }, label)
      .labelStyle({
        unselectedColor: $r('app.color.text_secondary'),
        selectedColor: accentColor()
      })
      .padding({ bottom: 0 });
  }

  private symbolFor(index: number): Resource {
    if (index === 1) {
      return $r('sys.symbol.list_bullet_square');
    }
    if (index === 2) {
      return $r('sys.symbol.bag');
    }
    if (index === 3) {
      return $r('sys.symbol.folder');
    }
    return $r('sys.symbol.doc_text');
  }

  build() {
    Stack() {
    HdsNavigation() {
      HdsTabs({ controller: this.hdsTabsController, index: this.activeTab }) {
        TabContent() {
          MenuLibraryTab({ pageScroller: this.libraryScroller })
        }
        .tabBar(this.hdsTabBar(this.symbolFor(0), '菜单库'))

        TabContent() {
          OrderTab({ pageScroller: this.orderScroller })
        }
        .tabBar(this.hdsTabBar(this.symbolFor(1), '点菜'))

        TabContent() {
          ShoppingTab({ pageScroller: this.shoppingScroller })
        }
        .tabBar(this.hdsTabBar(this.symbolFor(2), '采购'))

        TabContent() {
          PantryTab({ pageScroller: this.pantryScroller })
        }
        .tabBar(this.hdsTabBar(this.symbolFor(3), '食材'))
      }
      .width('100%')
      .height('100%')
      .barPosition(BarPosition.End)
      .barOverlap(true)
      .scrollable(true)
      .animationDuration(0)
      .attributeModifier(this.hdsTabsModifier)
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
    .bindToScrollable([this.libraryScroller, this.orderScroller, this.shoppingScroller, this.pantryScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

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
