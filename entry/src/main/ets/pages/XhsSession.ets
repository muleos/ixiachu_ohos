/**
 * 小红书访问凭证（v1.12.8，收藏 useWebSession 同款）：
 * 内置 WebView 打开小红书——Cookie/存储留在应用 WebView 容器内，
 * 解析请求自动携带该会话；建议浏览/打开任意一篇笔记后返回重试解析。
 */
import { webview } from '@kit.ArkWeb';
import { router } from '@kit.ArkUI';
import { topAvoid } from '../utils/Theme';

@Entry
@Component
struct XhsSession {
  private controller: webview.WebviewController = new webview.WebviewController();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  build() {
    Column() {
      // 顶栏
      Row({ space: 10 }) {
        Text('获取小红书访问凭证')
          .fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
        Blank()
        Text('完成')
          .fontSize(15).fontColor($r('app.color.accent'))
          .onClick((): void => {
            router.back();
          })
      }
      .width('100%')
      .padding({ top: topAvoid(this.statusBarHeight) + 8, left: 16, right: 16, bottom: 10 })

      Text('在下方浏览小红书（建议随便打开一篇笔记），然后点右上角「完成」返回重新解析')
        .fontSize(11).fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

      Web({ src: 'https://www.xiaohongshu.com', controller: this.controller })
        .width('100%')
        .layoutWeight(1)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .geolocationAccess(false)
        .onControllerAttached((): void => {
          try {
            // 与解析请求同款 UA：移动端 + xiaohongshu 后缀
            this.controller.setCustomUserAgent(
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36 xiaohongshu');
          } catch (e) {
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
