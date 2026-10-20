/**
 * FrostPage —— 二级页官方沉浸光感骨架（v1.10.0，VHome FrostScaffold 同款配方收敛）：
 * HdsNavigation MINI 顶栏（官方返回键 + IMMERSIVE_GRADIENT_BLUR 滚动渐变模糊）
 * + 内容首项 spacer 避让随滚动透出 + 尾部留白避让小白条。
 * 用法：
 *   Stack() {
 *     FrostPage({ title: '小票识别入库', scroller: this.scroller }) {
 *       // 页面内容（自带横向 padding），弹层放 FrostPage 之后的 Stack 悬浮层
 *     }
 *     if (this.showXxx) { ...遮罩弹层... }
 *   }
 */
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, DividerShowType,
  HdsNavigationMenuContentOptions, HdsNavigationMenuItemOptions } from '@kit.UIDesignKit';
import { queryStatusBarHeight, frostTitleStyle, topAvoid } from '../utils/Theme';

@Component
export struct FrostPage {
  @Prop title: string = '';
  /** 副标题（可选，MINI 顶栏小字） */
  @Prop subtitle: string = '';
  /** 页面主滚动容器（官方光感滚动源绑定） */
  scroller: Scroller = new Scroller();
  /** 右上角官方 menu 图标（可选，如详情页删除） */
  rightIcon: Resource | null = null;
  rightIconColor: Resource = $r('app.color.text_primary');
  onRight: () => void = (): void => {
  };
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  /** 窗口直查兜底（广播滞后/为 0 时顶栏避让依然正确） */
  @State queriedBar: number = 0;

  @BuilderParam content: () => void = this.emptyContent;

  aboutToAppear(): void {
    queryStatusBarHeight(getContext(this)).then((h: number): void => {
      if (h > 0) {
        this.queriedBar = h;
      }
    });
  }

  @Builder
  emptyContent() {
  }

  /** 状态栏高度：广播/直查取大者，36vp 兜底 */
  private inset(): number {
    return Math.max(Math.max(this.statusBarHeight, this.queriedBar), 36);
  }

  private menuOptions(): HdsNavigationMenuContentOptions | undefined {
    if (this.rightIcon !== null) {
      const item: HdsNavigationMenuItemOptions = {
        content: {
          icon: new SymbolGlyphModifier(this.rightIcon).fontColor([this.rightIconColor]),
          action: this.onRight
        }
      };
      return { value: [item] };
    }
    return undefined;
  }

  build() {
    HdsNavigation() {
      Scroll(this.scroller) {
        Column() {
          // 首项避让 spacer：随内容滚走，内容透出到标题栏后面（光感采样）
          Column().width('100%').padding({ top: topAvoid(this.inset()) + 12 })
          this.content()
          // 尾部留白：避让小白条手势区
          Column().height(48).width('100%')
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: {
          mainTitle: this.title,
          subTitle: this.subtitle.length > 0 ? this.subtitle : undefined
        },
        menu: this.menuOptions(),
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
  }
}
