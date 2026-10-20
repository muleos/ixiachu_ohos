/** 灵感 Tab —— 烹饪灵感与笔记：灵感盲盒 / 二十四节气时令推荐 / 风味搭配秘籍 */
import { router } from '@kit.ArkUI';
import { topAvoid } from '../../utils/Theme';
import { InspirationData, SeasonInfo } from '../../service/InspirationData';

@Component
export struct InspirationTab {
  pageScroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  /** 每日一条秘籍（按天轮换） */
  @State tipIndex: number = 0;
  private season: SeasonInfo = InspirationData.seasonOf(new Date());

  aboutToAppear(): void {
    const day: number = Math.floor(Date.now() / 86400000);
    this.tipIndex = Math.floor(day % InspirationData.tips.length);
  }

  build() {
    // v1.11.0 沉浸光感：首项 spacer 避让，内容透出到标题栏后面
    List({ scroller: this.pageScroller, space: 14 }) {
      ListItem() {
        Column().width('100%').height(topAvoid(this.statusBarHeight) + 12)
      }

      // ① 灵感盲盒 · 今天吃什么
      ListItem() {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Text('✦ 灵感盲盒').fontSize(11).fontColor(Color.White)
                .backgroundColor($r('app.color.accent'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10)
              Text('摇一摇抽卡').fontSize(11).fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            Text('今天吃什么').fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('纠结这一餐？轻触开启私房盲盒，邂逅今日味蕾奇遇')
              .fontSize(12).fontColor($r('app.color.text_secondary')).width('100%')
            Button('  开箱抽取 →  ')
              .height(34).borderRadius(17)
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .fontSize(13)
              .margin({ top: 2 })
              .onClick((): void => {
                router.pushUrl({ url: 'pages/InspirationMystery' });
              })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // 渐变盲盒小卡
          Column({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.gift'))
              .fontSize(26).fontColor([Color.White])
            Text('盲盒').fontSize(11).fontColor(Color.White)
            Text('✦').fontSize(9).fontColor('#B3FFFFFF')
          }
          .width(92)
          .height(118)
          .justifyContent(FlexAlign.Center)
          .borderRadius(16)
          .linearGradient({
            angle: 160,
            colors: [['#F08A3C', 0], ['#E8622D', 1]]
          })
          .shadow({ radius: 12, color: '#33E8622D', offsetY: 4 })
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_background'))
        .onClick((): void => {
          router.pushUrl({ url: 'pages/InspirationMystery' });
        })
      }

      // ② 二十四节气 · 时令推荐
      ListItem() {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Text('❋ 二十四节气').fontSize(11).fontColor($r('app.color.accent'))
                .backgroundColor($r('app.color.accent_soft'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10)
              Text(this.season.term + ' · 当令').fontSize(11).fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            Text('时令推荐').fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text(this.season.desc).fontSize(12).fontColor($r('app.color.text_secondary'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(`探索 ${this.season.matchCount()} 道好味 ›`)
              .fontSize(12).fontColor($r('app.color.accent'))
              .onClick((): void => {
                router.pushUrl({ url: 'pages/InspirationSeason' });
              })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column({ space: 4 }) {
            Text(this.season.key).fontSize(30).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent'))
            Text(`${this.season.term} · ${this.season.sub}`).fontSize(10)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(92)
          .height(118)
          .justifyContent(FlexAlign.Center)
          .borderRadius(16)
          .backgroundColor($r('app.color.accent_soft'))
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_background'))
        .onClick((): void => {
          router.pushUrl({ url: 'pages/InspirationSeason' });
        })
      }

      // ③ 风味搭配秘籍（按天轮换）
      ListItem() {
        Column({ space: 8 }) {
          Row() {
            Text('风味搭配秘籍').fontSize(17).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text('◈ 点睛香韵').fontSize(11).fontColor($r('app.color.accent'))
              .backgroundColor($r('app.color.accent_soft'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(10)
          }
          .width('100%')
          Text(InspirationData.tips[this.tipIndex])
            .fontSize(13).lineHeight(21).fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_background'))
        .alignItems(HorizontalAlign.Start)
      }

      ListItem() {
        Column().width('100%').height(92)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .edgeEffect(EdgeEffect.Spring)
  }
}
