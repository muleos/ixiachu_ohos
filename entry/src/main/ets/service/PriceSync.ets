/**
 * 云端菜价同步：
 * 从 GitHub prices 分支拉取 latest.json（惠友到家抓包数据 → 每日自动化生成），
 * 静默覆盖本地 NutritionDB 基准价。失败不影响使用（保持内置基准价）。
 */
import { http } from '@kit.NetworkKit';
import { applyPriceOverrides } from './NutritionDB';
import { DataStore } from './DataStore';

const PRICE_URL: string = 'https://raw.githubusercontent.com/muleos/ixiachu_ohos/prices/latest.json';
export const LAST_SYNC_KEY: string = 'price_last_sync';

export class PriceSync {
  /** 拉取并应用云端菜价；静默失败，返回是否成功 */
  static async sync(): Promise<boolean> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(PRICE_URL, {
        method: http.RequestMethod.GET,
        connectTimeout: 8000,
        readTimeout: 8000,
        header: { 'User-Agent: IXiaChu/1.4.0 }
      });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        return false;
      }
      const body: string = resp.result as string;
      if (body.length === 0) {
        return false;
      }
      const n: number = applyPriceOverrides(body);
      if (n > 0) {
        // 记录同步日期与覆盖条数，供采购页展示
        const file: object = JSON.parse(body) as object;
        const updated: string = (file as Record<string, string>)['updated'] ?? '';
        DataStore.setSetting(LAST_SYNC_KEY, updated.length > 0 ? updated : PriceSync.today());
        DataStore.setSetting('price_sync_count', String(n));
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      req.destroy();
    }
  }

  static today(): string {
    const d: Date = new Date();
    const m: string = String(d.getMonth() + 1).padStart(2, '0');
    const day: string = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}`;
  }
}
