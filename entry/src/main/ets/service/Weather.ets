/**
 * 气温服务（Open-Meteo 免费 API，无需密钥）：
 * 实时温度 → 新鲜度气候系数；缓存 6 小时，拉取失败回退月份代理。
 * v1.9.0：城市扩容至 30 城 + 定位模式——实时位置就近匹配城市，
 * 之后气温按定位坐标直取（比城市表坐标更准），手选城市随时覆盖。
 */
import { http } from '@kit.NetworkKit';
import { DataStore } from './DataStore';

const CITY_KEY: string = 'weather_city';
const MODE_KEY: string = 'weather_mode'; // auto=定位 city=手选
const LAT_KEY: string = 'weather_lat';
const LON_KEY: string = 'weather_lon';
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
  new City('郑州', 34.7466, 113.6254),
  new City('重庆', 29.5630, 106.5516),
  new City('天津', 39.3434, 117.3616),
  new City('苏州', 31.2989, 120.5853),
  new City('长沙', 28.2282, 112.9388),
  new City('沈阳', 41.8057, 123.4315),
  new City('哈尔滨', 45.8038, 126.5350),
  new City('青岛', 36.0671, 120.3826),
  new City('济南', 36.6512, 117.1201),
  new City('石家庄', 38.0428, 114.5149),
  new City('太原', 37.8706, 112.5489),
  new City('合肥', 31.8206, 117.2272),
  new City('福州', 26.0745, 119.2965),
  new City('厦门', 24.4798, 118.0894),
  new City('南昌', 28.6820, 115.8579),
  new City('昆明', 25.0389, 102.7183),
  new City('贵阳', 26.6470, 106.6302),
  new City('南宁', 22.8170, 108.3665),
  new City('海口', 20.0444, 110.1999),
  new City('兰州', 36.0611, 103.8343),
  new City('乌鲁木齐', 43.8256, 87.6168)
];

export class Weather {
  static cities(): string[] {
    return CITIES.map((c: City): string => c.name);
  }

  /** 当前是否为定位模式 */
  static isAuto(): boolean {
    return DataStore.getSetting(MODE_KEY) === 'auto';
  }

  static currentCity(): string {
    if (Weather.isAuto()) {
      const saved: string = DataStore.getSetting(CITY_KEY);
      return saved.length > 0 ? saved : '定位中';
    }
    const saved: string = DataStore.getSetting(CITY_KEY);
    return saved.length > 0 ? saved : '北京';
  }

  /** 城市展示名（带来源角标）：设置页/食材页提示用 */
  static cityLabel(): string {
    const name: string = Weather.currentCity();
    return Weather.isAuto() ? `${name}（定位）` : name;
  }

  /** 手选城市：清除定位坐标，气温按城市表坐标取 */
  static setCity(name: string): void {
    DataStore.setSetting(MODE_KEY, 'city');
    DataStore.setSetting(CITY_KEY, name);
    DataStore.setSetting(LAT_KEY, '');
    DataStore.setSetting(LON_KEY, '');
    Weather.clearCache();
  }

  /** 定位成功：记录定位坐标（气温按坐标直取），城市名取就近匹配 */
  static setAuto(cityName: string, lat: number, lon: number): void {
    DataStore.setSetting(MODE_KEY, 'auto');
    DataStore.setSetting(CITY_KEY, cityName);
    DataStore.setSetting(LAT_KEY, `${lat}`);
    DataStore.setSetting(LON_KEY, `${lon}`);
    Weather.clearCache();
  }

  private static clearCache(): void {
    DataStore.setSetting(TEMP_KEY, '');
    DataStore.setSetting(FETCH_AT_KEY, '');
  }

  /** 就近城市（haversine，单位 km）：定位点匹配城市名用 */
  static nearestCity(lat: number, lon: number): City {
    let best: City = CITIES[0];
    let bestKm: number = Number.MAX_VALUE;
    for (const c of CITIES) {
      const dLat: number = (c.lat - lat) * Math.PI / 180;
      const dLon: number = (c.lon - lon) * Math.PI / 180;
      const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2)
        + Math.cos(lat * Math.PI / 180) * Math.cos(c.lat * Math.PI / 180)
        * Math.sin(dLon / 2) * Math.sin(dLon / 2);
      const km: number = 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      if (km < bestKm) {
        bestKm = km;
        best = c;
      }
    }
    return best;
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

  /** 拉取坐标：定位模式用定位坐标（更准），手选模式查城市表 */
  private static coords(): City | undefined {
    if (Weather.isAuto()) {
      const latStr: string = DataStore.getSetting(LAT_KEY);
      const lonStr: string = DataStore.getSetting(LON_KEY);
      if (latStr.length > 0 && lonStr.length > 0) {
        const lat: number = parseFloat(latStr);
        const lon: number = parseFloat(lonStr);
        if (!isNaN(lat) && !isNaN(lon)) {
          return new City(Weather.currentCity(), lat, lon);
        }
      }
      return undefined;
    }
    return CITIES.find((c: City): boolean => c.name === Weather.currentCity());
  }

  private static async fetchTemp(): Promise<number> {
    const city: City | undefined = Weather.coords();
    if (city === undefined) {
      return -999;
    }
    const req: http.HttpRequest = http.createHttp();
    try {
      const url: string =
        `https://api.open-meteo.com/v1/forecast?latitude=${city.lat.toFixed(4)}&longitude=${city.lon.toFixed(4)}&current=temperature_2m&timezone=auto`;
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000,
        header: { 'User-Agent': 'IXiaChu/1.9.0' }
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
