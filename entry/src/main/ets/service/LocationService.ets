/**
 * 定位服务（v1.9.0 新增）：
 * 授权（模糊+精确位置）→ 取一次位置 → 交给 Weather 就近匹配城市。
 * 只在用户主动点「定位」时调用一次，不做后台定位、不上传坐标。
 */
import { abilityAccessCtrl, Permissions, common } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'LocationService';
const DOMAIN: number = 0x1CA;

export class LocateResult {
  ok: boolean = false;
  /** 失败原因文案（toast 直接可用） */
  message: string = '';
  lat: number = 0;
  lon: number = 0;
}

export class LocationService {
  private static readonly PERMS: Permissions[] = [
    'ohos.permission.APPROXIMATELY_LOCATION',
    'ohos.permission.LOCATION'
  ];

  /**
   * 取一次当前位置。
   * 成功 → ok=true 携带坐标；失败 → ok=false 带原因（权限拒绝/定位关闭/取位失败）。
   */
  static async locate(ctx: common.UIAbilityContext): Promise<LocateResult> {
    const out: LocateResult = new LocateResult();
    // 1. 权限：模糊位置为本功能最低要求，模糊+精确一起申请
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(ctx, LocationService.PERMS);
      const granted: boolean = (res.authResults ?? []).some((r: number): boolean => r === 0);
      if (!granted) {
        out.message = '未获得定位权限，可手选城市或在系统设置中开启';
        return out;
      }
    } catch (e) {
      out.message = '定位权限请求失败，可手选城市';
      return out;
    }
    // 2. 开关：位置服务被关时引导
    try {
      if (!geoLocationManager.isLocationEnabled()) {
        out.message = '定位服务未开启，请在控制中心或系统设置中打开';
        return out;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'isLocationEnabled failed: %{public}s', (e as Error).message);
    }
    // 3. 取位：优先最近一次缓存位置（秒级返回），无效再请求实时定位
    try {
      let loc: geoLocationManager.Location | null = null;
      try {
        loc = geoLocationManager.getLastLocation();
      } catch (e) {
        loc = null;
      }
      if (loc === null || loc.latitude === 0 || loc.longitude === 0) {
        loc = await geoLocationManager.getCurrentLocation();
      }
      out.ok = true;
      out.lat = loc.latitude;
      out.lon = loc.longitude;
      hilog.info(DOMAIN, TAG, 'locate ok lat=%{public}f lon=%{public}f', out.lat, out.lon);
      return out;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getCurrentLocation failed: %{public}s', (e as Error).message);
      out.message = '定位失败，请稍后重试或手选城市';
      return out;
    }
  }
}
