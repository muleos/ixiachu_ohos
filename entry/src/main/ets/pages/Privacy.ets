/** 隐私政策 —— 内置全文页（离线可看，AGC 审核友好），设置页与首启弹窗均可进入 */
import { router } from '@kit.ArkUI';
import { queryStatusBarHeight } from '../utils/Theme';

const PRIVACY_TEXT: string = `更新日期：2026-10-20　版本：v1.9.0

「I下厨」（以下简称"本应用"）是一款本地菜谱管理与点菜助手工具。我们非常重视您的隐私，本政策说明本应用如何处理信息。

一、我们收集哪些信息
1. 本应用不要求注册、不登录、不收集您的姓名、手机号、邮箱等任何身份信息。
2. 您在使用中录入的菜谱、菜单、采购清单、食材库存、小票识别结果与手动修正记录，均仅保存在您设备本地的应用数据目录中，不上传到任何服务器。
3. 本应用不包含广告、不接入任何第三方统计或追踪 SDK。

二、联网说明
本应用仅在以下情形发起网络请求：
1. 云端菜价同步：从 GitHub（raw.githubusercontent.com）读取菜价参考数据，请求中不含任何个人信息；
2. 气温查询：向 Open-Meteo（api.open-meteo.com）查询当前位置或所选城市的气温，仅发送城市坐标，不发送设备标识或个人信息。
除上述两类只读请求外，本应用不会向任何服务器发送您的数据。

三、系统能力说明
1. 相机/相册：小票识别使用系统相机拍摄或相册选图，照片仅在设备本地处理（系统文字识别能力），不会上传。
2. 位置信息（可选）：仅当您在设置页主动点击「定位」时，本应用读取一次当前位置，用于就近匹配城市、获取当地实时气温以修正新鲜度估算与时令推荐；坐标仅在本机使用，不写入日志、不上传服务器；您也可以随时改用手动选择城市。
3. 通知：临期提醒使用系统本地通知，仅在您授权后发送，可在系统设置中关闭。
4. 桌面卡片：显示您最近确认的菜单与临期食材摘要，数据来自本地。

四、数据存储与删除
1. 全部数据保存在设备本地，卸载应用即彻底删除。
2. 您可在应用内随时清除本地数据（设置 → 清空本地小票菜价；卸载重装可重置全部数据）。

五、未成年人保护
本应用面向一般用户，不主动向未成年人收集任何信息。

六、政策更新
如本政策发生重大变更，将在应用更新说明中标注并更新版本日期。

如您对本政策有任何疑问，可通过应用市场页面联系开发者。`;

@Entry
@Component
struct Privacy {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @State queriedBar: number = 0;

  aboutToAppear(): void {
    queryStatusBarHeight(getContext(this)).then((h: number): void => {
      if (h > 0) {
        this.queriedBar = h;
      }
    });
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
          .onClick((): void => {
            router.back();
          })
        Text('隐私政策')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .padding({ left: 12, right: 20, top: Math.max(Math.max(this.statusBarHeight, this.queriedBar), 36) })

      Scroll() {
        Text(PRIVACY_TEXT)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 20, right: 20, top: 12, bottom: 40 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
