/**
 * I下厨 主框架 —— 与 CoolapkPura 同款官方槽位：
 * HdsNavigation 顶栏（沉浸光感渐变模糊）+ HdsTabs 悬浮胶囊底栏（barFloatingStyle）。
 * 底栏：barHeight 56 / barBottomMargin 30 / IMMERSIVE 材质，选中色 = 品牌 accent。
 * 顶栏：IMMERSIVE_GRADIENT_BLUR 滚动光感，bindToScrollable 绑定各页滚动器。
 */
import { LengthMetrics, SymbolGlyphModifier, mediaquery } from '@kit.ArkUI';
import {
  HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController, HdsTabsModifier,
  hdsMaterial, DividerShowType, ScrollEffectType, TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { accentColor } from '../utils/Theme';
import { MenuLibraryTab } from './tabs/MenuLibraryTab';
import { OrderTab } from './tabs/OrderTab';
import { ShoppingTab } from './tabs/ShoppingTab';
import { PantryTab } from './tabs/PantryTab';

const TAB_BAR_HEIGHT: number = 56;

@Entry
@Component
struct MainTab {
  @StorageProp('isDarkMode') @Watch('onThemeChanged') isDark: boolean = false;
  @State activeTab: number = 0;
  @State hdsTabsModifier: HdsTabsModifier = new HdsTabsModifier();
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  private libraryScroller: Scroller = new Scroller();
  private orderScroller: Scroller = new Scroller();
  private shoppingScroller: Scroller = new Scroller();
  private pantryScroller: Scroller = new Scroller();
  private mqListener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    this.configureHdsTabs();
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

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(16)
      },
      originalStyle: {
        backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background_transparent') },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: { backgroundColor: $r('app.color.page_background') },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    };
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
      style: this.titleBarStyle(),
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
  }
}
