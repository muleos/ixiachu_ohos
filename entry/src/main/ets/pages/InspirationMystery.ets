/**
 * 灵感盲盒 · 今天吃什么（v1.11.0）：
 * 渐变盲盒卡 → 抽取菜单库随机菜谱 → 风味签卡（标签/随笔/食材步数）
 * → 换一道重抽 / 就吃这个了（跳菜谱详情）。
 */
import { router, promptAction } from '@kit.ArkUI';
import { Recipe } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct InspirationMystery {
  private scroller: Scroller = new Scroller();
  /** 已抽取的菜谱（null=未开启盲盒态） */
  @State drawn: Recipe | null = null;
  /** 重抽计数（驱动卡面刷新） */
  @State drawKey: number = 0;

  private draw(): void {
    const pool: Recipe[] = DataStore.getRecipes();
    if (pool.length === 0) {
      promptAction.showToast({ message: '菜单库还是空的，先导入或手动创建一道菜吧' });
      return;
    }
    const i: number = Math.floor(Math.random() * pool.length);
    this.drawn = pool[i];
    this.drawKey++;
  }

  private openDrawn(): void {
    const r: Recipe | null = this.drawn;
    if (r === null) {
      return;
    }
    AppStorage.setOrCreate<string>('currentRecipeId', r.id);
    router.pushUrl({ url: 'pages/RecipeDetail' });
  }

  build() {
    Stack() {
    FrostPage({ title: '今天吃什么', subtitle: '轻点卡片或摇一摇抽取今日惊喜', scroller: this.scroller }) {
      Column({ space: 16 }) {
        if (this.drawn === null) {
          // 盲盒未开启态：渐变卡
          Column({ space: 14 }) {
            Text('✦  CHEF\'S TASTING MYSTERY  ✦')
              .fontSize(10).fontColor('#B3FFFFFF').letterSpacing(2)
            Column({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.lightbulb_fill'))
                .fontSize(38).fontColor([Color.White])
            }
            .width(84)
            .height(84)
            .justifyContent(FlexAlign.Center)
            .borderRadius(42)
            .backgroundColor('#4DFFFFFF')
            Text('今日风味盲盒').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('轻触开启主厨厨房惊喜').fontSize(13).fontColor('#E6FFFFFF')
            Text('✦  PRIVATE KITCHEN  ✦')
              .fontSize(9).fontColor('#99FFFFFF').letterSpacing(2)
          }
          .width('100%')
          .padding({ top: 40, bottom: 36 })
          .borderRadius(22)
          .linearGradient({ angle: 165, colors: [['#F08A3C', 0], ['#E8622D', 1]] })
          .shadow({ radius: 24, color: '#44E8622D', offsetY: 8 })
        } else {
          // 抽中态：风味签卡
          Column({ space: 12 }) {
            Column({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.lightbulb_fill'))
                .fontSize(30).fontColor([$r('app.color.accent')])
              Text('✦ 私厨风味签 ✦').fontSize(11).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ top: 22, bottom: 12 })
            .linearGradient({ angle: 180, colors: [['#FDEFE7', 0], ['#FFFFFF', 1]] })

            Column({ space: 10 }) {
              Text((this.drawn as Recipe).name)
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                .width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach((this.drawn as Recipe).tags, (t: string): void => {
                  Text(t).fontSize(11).fontColor($r('app.color.accent'))
                    .backgroundColor($r('app.color.accent_soft'))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(9)
                    .margin({ right: 6, bottom: 6 })
                }, (t: string): string => t)
              }
              .width('100%')
              if ((this.drawn as Recipe).tip.length > 0) {
                Text((this.drawn as Recipe).tip)
                  .fontSize(13).lineHeight(21).fontColor($r('app.color.text_secondary')).width('100%')
              }
              Divider().color($r('app.color.divider')).strokeWidth(0.5)
              Row() {
                Text(`${(this.drawn as Recipe).ingredients.length} 种食材`)
                  .fontSize(12).fontColor($r('app.color.text_secondary'))
                Blank()
                Text(`${(this.drawn as Recipe).steps.length} 步操作`)
                  .fontSize(12).fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .borderRadius(22)
          .backgroundColor($r('app.color.card_background'))
          .clip(true)
        }

        // 操作按钮
        if (this.drawn === null) {
          Button('✦  开启今日味蕾盲盒  ✦')
            .width('100%')
            .height(48).borderRadius(24)
            .fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .linearGradient({ angle: 90, colors: [['#F08A3C', 0], ['#E8622D', 1]] })
            .onClick((): void => {
              this.draw();
            })
        } else {
          Row({ space: 12 }) {
            Button('换一道，重新抽')
              .layoutWeight(1)
              .height(46).borderRadius(23)
              .backgroundColor($r('app.color.card_background'))
              .fontColor($r('app.color.text_secondary'))
              .fontSize(15)
              .onClick((): void => {
                this.draw();
              })
            Button('就吃这个了！')
              .layoutWeight(1)
              .height(46).borderRadius(23)
              .fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .linearGradient({ angle: 90, colors: [['#F08A3C', 0], ['#E8622D', 1]] })
              .onClick((): void => {
                this.openDrawn();
              })
          }
          .width('100%')
        }

        Text('菜谱来自你的菜单库，去录入属于你的 ')
          .fontSize(12).fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            router.pushUrl({ url: 'pages/RecipeManual' });
          })

        Column().width('100%').height(20)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    }
  }
}
