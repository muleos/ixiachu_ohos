/**
 * I下厨 主题与设计令牌。
 * 深浅色统一走 resources/dark 限定词（$r 自动切换）；
 * 此处提供 AppStorage 广播与少量动态取色工具，供 dock/玻璃层使用。
 */
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

const TAG: string = 'Theme';

export const PRIMARY_LIGHT: string = '#E8622D';
export const PRIMARY_DARK: string = '#F07B45';

/**
 * HdsNavigation MINI 顶栏高度（vp）。
 * 沉浸式下顶栏浮于内容上层，页内首行需避让：statusBarHeight + NAV_TITLE_HEIGHT。
 */
export const NAV_TITLE_HEIGHT: number = 48;

/** 玻璃 dock 白玻璃描边（浅深通用半透明） */
export function glassBorder(): string {
  return AppStorage.get<boolean>('isDarkMode') === true ? '#33FFFFFF' : '#66FFFFFF';
}

/** 取当前 accent 色 */
export function accentColor(): string {
  return AppStorage.get<boolean>('isDarkMode') === true ? PRIMARY_DARK : PRIMARY_LIGHT;
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
    const ui: UIContext = win.getUIContext();
    const sysArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const statusH: number = ui.px2vp(sysArea.topRect.height);
    AppStorage.setOrCreate<number>('statusBarHeight', statusH);
    AppStorage.setOrCreate<number>('navBarHeight', 0);
  } catch (e) {
  }
}
