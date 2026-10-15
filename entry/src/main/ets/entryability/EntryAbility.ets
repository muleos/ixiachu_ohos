/**
 * I下厨 主入口 Ability —— 沉浸式方案参照 VHome：
 * 全屏布局 + 状态栏透明 + 内容色随深浅色反色 + 小白条 0 避让。
 */
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { applyTheme, publishInsets } from '../utils/Theme';
import { SeedService } from '../service/SeedService';
import { PriceSync } from '../service/PriceSync';

const DOMAIN: number = 0x1C8;
const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private darkModeEnabled: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 预种全局键：@StorageProp 对挂载时后补的 key 同步不可靠
    AppStorage.setOrCreate<boolean>('isDarkMode', false);
    AppStorage.setOrCreate<number>('statusBarHeight', 0);
    AppStorage.setOrCreate<number>('navBarHeight', 0);
    AppStorage.setOrCreate<number>('dataRev', 0);
    AppStorage.setOrCreate<number>('shoppingRev', 0);
    hilog.info(DOMAIN, TAG, 'onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const mainWindow = windowStage.getMainWindowSync();
    this.mainWindow = mainWindow;
    mainWindow.setWindowLayoutFullScreen(true).catch((err: Error): void => {
      hilog.error(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', err.message);
    });
    // 键盘避让用压缩模式：输入条贴键盘上沿，不露系统灰底
    try {
      mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setKeyboardAvoidMode throw: %{public}s', (err as Error).message);
    }
    // 首帧默认浅色；深浅色切换由 onConfigurationUpdate 统一接管
    windowStage.loadContent('pages/MainTab', (err): void => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      publishInsets(mainWindow);
      mainWindow.on('avoidAreaChange', (): void => {
        publishInsets(mainWindow);
      });
      // 兜底：个别机型首帧后避让区才就绪
      setTimeout((): void => {
        publishInsets(mainWindow);
      }, 200);
      setTimeout((): void => {
        publishInsets(mainWindow);
      }, 900);
    });
    this.syncTheme();
    // 首启种入「下厨房精选」菜谱（异步，不阻塞首帧）
    SeedService.seedIfNeed(this.context);
    // 启动静默同步云端菜价（惠友到家数据 → GitHub prices 分支），失败不影响使用
    PriceSync.sync().catch((): void => {
    });
  }

  private syncTheme(): void {
    const win = this.mainWindow;
    if (win === null) {
      return;
    }
    applyTheme(win, this.darkModeEnabled);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const dark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    if (dark === this.darkModeEnabled) {
      return;
    }
    this.darkModeEnabled = dark;
    this.syncTheme();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }
}
