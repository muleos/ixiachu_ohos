/**
 * 临期通知：
 * App 启动时异步检查临期食材（SOON/CHECK 级），有临期且当天未发过时发本地通知；
 * 点击通知回到「食材管理」页。首次发布前请求通知授权（拒绝则关闭开关，设置页可再开）。
 * 频控：一天最多一条（preferences 记 lastNotifyDate）。
 */
import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, common } from '@kit.AbilityKit';
import { DataStore } from './DataStore';
import { Freshness } from './Freshness';
import { FreshLevel, StockItem } from '../model/Models';

const NOTIFY_KEY: string = 'expiry_notify_on';
const LAST_NOTIFY_KEY: string = 'expiry_last_date';
const ASKED_KEY: string = 'notify_asked';
const NOTIFY_ID: number = 1001;

export class Notify {
  /** 临期提醒开关（默认开启，拒绝授权后置关） */
  static enabled(): boolean {
    return DataStore.getSetting(NOTIFY_KEY) !== '0';
  }

  static setEnabled(on: boolean): void {
    DataStore.setSetting(NOTIFY_KEY, on ? '1' : '0');
  }

  static todayStr(): string {
    const d: Date = new Date();
    const m: string = String(d.getMonth() + 1).padStart(2, '0');
    const day: string = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}`;
  }

  /** 临期食材列表（SOON/CHECK 级，月份代理口径） */
  private static urgentItems(): StockItem[] {
    const now: Date = new Date();
    return DataStore.getStock().filter((s: StockItem): boolean =>
      Freshness.level(Freshness.decayRatioSync(s, now, Freshness.monthFactor(now))) >= FreshLevel.SOON);
  }

  /**
   * 启动检查入口（异步，静默失败）：
   * 开关关 / 今日已发 / 无临期 → 跳过；
   * 首次先弹系统授权（拒绝：关闭开关，之后只走设置页入口）；
   * 已授权才发布，发布成功记频控日期。
   */
  static async checkAndPublish(context: common.UIAbilityContext): Promise<void> {
    try {
      if (!Notify.enabled()) {
        return;
      }
      if (DataStore.getSetting(LAST_NOTIFY_KEY) === Notify.todayStr()) {
        return;
      }
      const urgent: StockItem[] = Notify.urgentItems();
      if (urgent.length === 0) {
        return;
      }
      const names: string = urgent.slice(0, 2).map((s: StockItem): string => s.name).join('、');
      const text: string =
        `${urgent.length} 项食材临期（${names}${urgent.length > 2 ? ' 等' : ''}），建议尽快食用`;
      // 首次使用弹授权；拒绝则关开关（不再弹，设置页有入口）
      if (DataStore.getSetting(ASKED_KEY) !== '1') {
        try {
          await notificationManager.requestEnableNotification(context);
          DataStore.setSetting(ASKED_KEY, '1');
        } catch (e) {
          DataStore.setSetting(ASKED_KEY, '1');
          Notify.setEnabled(false);
          return;
        }
      } else {
        const enabled: boolean = await notificationManager.isNotificationEnabled();
        if (!enabled) {
          return;
        }
      }
      // 点击通知拉起主页并切到食材管理 Tab
      const agent = await wantAgent.getWantAgent({
        requestCode: 0,
        wants: [{
          bundleName: 'com.hmos.ixiachu',
          abilityName: 'EntryAbility',
          parameters: { launchTab: 4 }
        }]
      });
      const request: notificationManager.NotificationRequest = {
        id: NOTIFY_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'I下厨',
            text: text,
            additionalText: '点击查看食材管理'
          }
        },
        notificationSlotType: notificationManager.SlotType.CONTENT_INFORMATION,
        wantAgent: agent
      };
      await notificationManager.publish(request);
      DataStore.setSetting(LAST_NOTIFY_KEY, Notify.todayStr());
    } catch (e) {
      // 通知链路任何异常都不影响主流程
    }
  }
}
