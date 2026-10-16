/**
 * 气温服务（Open-Meteo 免费 API，无需密钥）：
 * 实时温度 → 新鲜度气候系数；缓存 6 小时，拉取失败回退月份代理。
 * 城市手选（默认北京），坐标内置城市表。
 */
import { http } from '@kit.NetworkKit';
import { DataStore } from './DataStore';

const CITY_KEY: string = 'weather_city';
const TEMP_KEY: string = 'weather_temp';
const FETCH_AT_KEY: string = 'weather_fetch_at';
const CACHE_MS: number = 6 * 3600 * 1000;

export class City {
  name: string = '';
  lat: number = 0;
  lon: number = 0;

  constructor(name: string, lat: number, lon: number) {
    this.name = name;
    this.lat = lat;
    this.lon = lon;
  }
}

const CITIES: City[] = [
  new City('北京', 39.9042, 116.4074),
  new City('上海', 31.2304, 121.4737),
  new City('广州', 23.1291, 113.2644),
  new City('深圳', 22.5431, 114.0579),
  new City('成都', 30.5728, 104.0668),
  new City('杭州', 30.2741, 120.1551),
  new City('武汉', 30.5928, 114.3055),
  new City('西安', 34.3416, 108.9398),
  new City('南京', 32.0603, 118.7969),
  new City('郑州', 34.7466, 113.6254)
];

export class Weather {
  static cities(): string[] {
    return CITIES.map((c: City): string => c.name);
  }

  static currentCity(): string {
    const saved: string = DataStore.getSetting(CITY_KEY);
    return saved.length > 0 ? saved : '北京';
  }

  /** 切换城市并清缓存（下次取系数时重新拉取） */
  static setCity(name: string): void {
    DataStore.setSetting(CITY_KEY, name);
    DataStore.setSetting(TEMP_KEY, '');
    DataStore.setSetting(FETCH_AT_KEY, '');
  }

  /**
   * 当前新鲜度气候系数：
   * 有可用温度（缓存或拉取成功）按温度分段；否则按月份代理。
   * <10°C 0.7（低温减缓变质）；10~25°C 1.0；>25°C 每 5° +0.15，封顶 2.0。
   */
  static async climateFactor(now: Date): Promise<number> {
    const temp: number = await Weather.currentTemp();
    if (temp === -999) {
      return Weather.monthFactor(now);
    }
    if (temp < 10) {
      return 0.7;
    }
    if (temp <= 25) {
      return 1.0;
    }
    return Math.min(2.0, 1.0 + Math.ceil((temp - 25) / 5) * 0.15);
  }

  /** 月份代理（无温度数据时）：6~8 月 1.5；12~2 月 0.7；其余 1.0 */
  static monthFactor(now: Date): number {
    const m: number = now.getMonth() + 1;
    if (m >= 6 && m <= 8) {
      return 1.5;
    }
    if (m === 12 || m <= 2) {
      return 0.7;
    }
    return 1.0;
  }

  /** 当前温度（缓存 6h；-999 表示不可用） */
  static async currentTemp(): Promise<number> {
    const now: number = Date.now();
    const cached: string = DataStore.getSetting(TEMP_KEY);
    const at: string = DataStore.getSetting(FETCH_AT_KEY);
    const atNum: number = at.length > 0 ? parseInt(at, 10) : 0;
    if (cached.length > 0 && atNum > 0 && now - atNum < CACHE_MS) {
      const t: number = parseFloat(cached);
      return isNaN(t) ? -999 : t;
    }
    const fetched: number = await Weather.fetchTemp();
    if (fetched !== -999) {
      DataStore.setSetting(TEMP_KEY, `${fetched}`);
      DataStore.setSetting(FETCH_AT_KEY, `${now}`);
    }
    return fetched;
  }

  /** 最近一次成功温度（纯缓存读取，不发起网络；-999 表示无）——页面展示用 */
  static cachedTemp(): number {
    const cached: string = DataStore.getSetting(TEMP_KEY);
    if (cached.length === 0) {
      return -999;
    }
    const t: number = parseFloat(cached);
    return isNaN(t) ? -999 : t;
  }

  /** 气温状态文案（食材页顶部展示）：有温度显示城市+温度+影响，无温度显示季节提示 */
  static hintText(): string {
    const t: number = Weather.cachedTemp();
    if (t === -999) {
      const f: number = Weather.monthFactor(new Date());
      if (f > 1.0) {
        return '高温季，食材变质加速';
      }
      if (f < 1.0) {
        return '低温季，食材更耐存';
      }
      return '';
    }
    const city: string = Weather.currentCity();
    const tempStr: string = `${city} ${Math.round(t)}°C`;
    if (t < 10) {
      return `${tempStr} · 低温更耐存`;
    }
    if (t <= 25) {
      return `${tempStr} · 温度适宜`;
    }
    return `${tempStr} · 高温加速变质`;
  }

  private static async fetchTemp(): Promise<number> {
    const city: City | undefined = CITIES.find((c: City): boolean => c.name === Weather.currentCity());
    if (city === undefined) {
      return -999;
    }
    const req: http.HttpRequest = http.createHttp();
    try {
      const url: string =
        `https://api.open-meteo.com/v1/forecast?latitude=${city.lat}&longitude=${city.lon}&current=temperature_2m&timezone=auto`;
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000,
        header: { 'User-Agent: IXiaChu/1.5.1 }
      });
      if (resp.responseCode !== 200) {
        return -999;
      }
      const body: string = typeof resp.result === 'string' ? resp.result : '';
      const obj: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const current: Record<string, Object> | undefined =
        obj['current'] as Record<string, Object> | undefined;
      if (current === undefined) {
        return -999;
      }
      const t: number = current['temperature_2m'] as number;
      return typeof t === 'number' ? t : -999;
    } catch (e) {
      return -999;
    } finally {
      req.destroy();
    }
  }
}
