/**
 * CrashLog（v1.11.7 新增，VHome CrashGuard 精简版）：
 * 全局注册未捕获异常 / 未处理 Promise rejection 观察者，
 * 写入 hilog + 应用沙箱 files/crash.log——闪退现场可落盘取证。
 * 注意：ErrorObserver 只能记录，拦不住进程退出；业务层 try/catch 兜底才是
 * 不闪退的主力（v1.11.6 已铺满解析链路），本层负责「真凶取证」。
 */
import { errorManager, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';

const DOMAIN: number = 0x1CA;
const TAG: string = 'CrashLog';

export class CrashLog {
  private static ctx: common.UIAbilityContext | null = null;

  /** 必须在 EntryAbility.onCreate 调用 */
  static install(ctx: common.UIAbilityContext): void {
    CrashLog.ctx = ctx;
    try {
      const observer: errorManager.ErrorObserver = {
        onUnhandledException: (errMsg: string): void => {
          hilog.error(DOMAIN, TAG, 'unhandled exception: %{public}s', errMsg);
          CrashLog.write('exception', errMsg);
        }
      };
      errorManager.on('error', observer);
      // 未被 .catch 的 Promise rejection 同样会杀进程；箭头函数直接作观察者
      errorManager.on('unhandledRejection', (reason: Object): void => {
        const msg: string = reason instanceof Error ? reason.message : String(reason);
        hilog.error(DOMAIN, TAG, 'unhandled rejection: %{public}s', msg);
        CrashLog.write('rejection', msg);
      });
      hilog.info(DOMAIN, TAG, 'crash log installed');
    } catch (e) {
      // 注册失败不影响启动
    }
  }

  /** 追加一条异常记录到 files/crash.log（超 64KB 清空重写） */
  private static write(kind: string, msg: string): void {
    if (CrashLog.ctx === null) {
      return;
    }
    try {
      const path: string = `${CrashLog.ctx.filesDir}/crash.log`;
      const line: string = `${new Date().toISOString()} [${kind}] ${msg}\n`;
      let mode: number = fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND;
      try {
        if (fileIo.accessSync(path) && fileIo.statSync(path).size > 65536) {
          mode = fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC;
        }
      } catch (e) {
      }
      const out: fileIo.File = fileIo.openSync(path, mode);
      try {
        fileIo.writeSync(out.fd, line);
      } finally {
        fileIo.closeSync(out);
      }
    } catch (e) {
      // 落盘失败不影响运行
    }
  }
}
