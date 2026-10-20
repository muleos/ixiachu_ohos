/**
 * I下厨 主题与设计令牌。
 * 深浅色统一走 resources/dark 限定词（$r 自动切换）；
 * 此处提供 AppStorage 广播与少量动态取色工具，供 dock/玻璃层使用。
 */
import { common } from '@kit.AbilityKit';
import { window, display, LengthMetrics } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ScrollEffectType, TitleBarStyleOptions, HdsTitleBarContentStyle, hdsMaterial } from '@kit.UIDesignKit';

const TAG: string = 'Theme';
const DOMAIN: number = 0x1C9;

export const PRIMARY_LIGHT: string = '#E8622D';
export const PRIMARY_DARK: string = '#F07B45';

/**
 * HdsNavigation MINI 顶栏高度（vp）。
 * 沉浸式下顶栏浮于内容上层，页内首行需避让：topAvoid() = max(statusBarHeight, 36) + NAV_TITLE_HEIGHT。
 * 取 56 留足余量（MINI 顶栏实测 44~56vp，机型有差异）。
 */
export const NAV_TITLE_HEIGHT: number = 56;
/** 状态栏兜底高度：发布失败时也不允许内容顶进状态栏 */
export const STATUS_BAR_FALLBACK: number = 36;

/** 页内首行总避让高度（vp） */
export function topAvoid(statusBarHeight: number): number {
  return Math.max(statusBarHeight, STATUS_BAR_FALLBACK) + NAV_TITLE_HEIGHT;
}

/**
 * 沉浸光感标题栏样式（v1.9.0，VHome FrostScaffold 同款配方）：
 * 未滚动全透明 + 滚动后 IMMERSIVE_GRADIENT_BLUR 渐变模糊采样 + 官方 IMMERSIVE 材质。
 * 前提：页面滚动内容可透出到标题栏后面（首项 spacer 避让，随内容滚走）。
 * 主框架与二级页（设置等）共用，深浅色走 $r 资源自适应。
 */
export function frostTitleStyle(): TitleBarStyleOptions {
  const contentStyle: HdsTitleBarContentStyle = {
    titleStyle: {
      mainTitleColor: $r('app.color.text_primary'),
      subTitleColor: $r('app.color.text_secondary')
    },
    backIconStyle: { iconColor: $r('app.color.text_primary') },
    subIconStyle: { iconColor: $r('app.color.text_primary') },
    menuStyle: { iconColor: $r('app.color.text_primary') }
  };
  return {
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(16)
    },
    originalStyle: {
      backgroundStyle: { backgroundColor: Color.Transparent },
      contentStyle: contentStyle
    },
    scrollEffectStyle: {
      backgroundStyle: { backgroundColor: $r('app.color.page_background') },
      contentStyle: contentStyle
    },
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }
  };
}

/** 玻璃 dock 白玻璃描边（浅深通用半透明） */
export function glassBorder(): string {
  return AppStorage.get<boolean>('isDarkMode') === true ? '#33FFFFFF' : '#66FFFFFF';
}

/** 取当前 accent 色 */
export function accentColor(): string {
  return AppStorage.get<boolean>('isDarkMode') === true ? PRIMARY_DARK : PRIMARY_LIGHT;
}

/**
 * 页面挂载时直接查询当前窗口状态栏高度（vp），不依赖 AppStorage 广播。
 * 广播可能在页面挂载前未发布或值滞后，二级页自查一次最可靠；查询失败返回 0。
 */
export async function queryStatusBarHeight(context: Context): Promise<number> {
  try {
    const win: window.Window = await window.getLastWindow(context);
    const sysArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const px: number = sysArea.topRect.height;
    if (px <= 0) {
      return 0;
    }
    let vp: number = 0;
    try {
      vp = win.getUIContext().px2vp(px);
    } catch (e) {
      vp = 0;
    }
    if (vp <= 0) {
      try {
        vp = px / display.getDefaultDisplaySync().densityPixels;
      } catch (e) {
        vp = 0;
      }
    }
    if (vp <= 0) {
      vp = px / 3.3;
    }
    return vp;
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'queryStatusBarHeight failed: %{public}s', (e as Error).message);
    return 0;
  }
}

/**
 * 在 Ability 启动与深浅色切换时调用：
 * 广播 isDarkMode / statusBarHeight / navBarHeight，供全应用 @StorageProp 订阅。
 */
export function applyTheme(win: window.Window, dark: boolean): void {
  AppStorage.setOrCreate<boolean>('isDarkMode', dark);
  try {
    win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: dark ? '#FFFFFF' : '#000000',
      navigationBarColor: '#00000000',
      navigationBarContentColor: dark ? '#FFFFFFFF' : '#FF1A1A1A'
    });
  } catch (e) {
  }
  try {
    win.setWindowBackgroundColor(dark ? '#191919' : '#F3F4F6');
  } catch (e) {
  }
  publishInsets(win);
}

/** 广播安全区高度（vp）。小白条区 0 避让——内容直达屏幕底部。 */
export function publishInsets(win: window.Window): void {
  try {
    const sysArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const px: number = sysArea.topRect.height;
    let vp: number = 0;
    try {
      vp = win.getUIContext().px2vp(px);
    } catch (e) {
      vp = 0;
    }
    if (vp <= 0 && px > 0) {
      // px2vp 不可用时按屏幕密度换算
      try {
        vp = px / display.getDefaultDisplaySync().densityPixels;
      } catch (e) {
        vp = 0;
      }
    }
    if (vp <= 0 && px > 0) {
      vp = px / 3.3; // 常见手机密度最后兜底
    }
    hilog.info(DOMAIN, TAG, 'publishInsets px=%{public}d vp=%{public}f', px, vp);
    AppStorage.setOrCreate<number>('statusBarHeight', vp);
    AppStorage.setOrCreate<number>('navBarHeight', 0);
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'publishInsets failed: %{public}s', (e as Error).message);
  }
}
