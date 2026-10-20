/**
 * 时令推荐（v1.11.0）：四季 chips（春鲜/夏清/秋润/冬藏）+ 当季节气卡 + 本季好味
 * （菜单库按当季食材关键词匹配，不足随机补齐），卡片点击进菜谱详情。
 */
import { router } from '@kit.ArkUI';
import { Recipe } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { InspirationData, SeasonInfo } from '../service/InspirationData';
import { FrostPage } from '../components/FrostPage';

@Entry
@Component
struct InspirationSeason {
  private scroller: Scroller = new Scroller();
  @State seasonKey: string = '';
  /** 筛选计数刷新键 */
  @State rev: number = 0;

  aboutToAppear(): void {
    this.seasonKey = InspirationData.seasonOf(new Date()).key;
  }

  private info(): SeasonInfo {
    return InspirationData.seasonByKey(this.seasonKey.length > 0 ? this.seasonKey : '秋');
  }

  private picks(): Recipe[] {
    return InspirationData.matchSeason(this.seasonKey.length > 0 ? this.seasonKey : '秋');
  }

  private difficulty(steps: number): string {
    if (steps <= 3) {
      return '简单';
    }
    if (steps <= 6) {
      return '中等';
    }
    return '进阶';
  }

  build() {
    Stack() {
    FrostPage({ title: '时令推荐', subtitle: '四时风物 · 本地精选', scroller: this.scroller }) {
      Column({ space: 14 }) {
        // 四季 chips
        Row({ space: 10 }) {
          ForEach(['春', '夏', '秋', '冬'], (k: string): void => {
            Column({ space: 2 }) {
              Text(k).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor(this.seasonKey === k ? Color.White : $r('app.color.text_primary'))
              Text(InspirationData.seasonByKey(k).sub).fontSize(10)
                .fontColor(this.seasonKey === k ? '#E6FFFFFF' : $r('app.color.text_tertiary'))
            }
            .layoutWeight(1)
            .padding({ top: 10, bottom: 10 })
            .borderRadius(14)
            .backgroundColor(this.seasonKey === k ? $r('app.color.accent') : $r('app.color.card_background'))
            .onClick((): void => {
              this.seasonKey = k;
              this.rev++;
            })
          }, (k: string): string => k)
        }
        .width('100%')

        // 季节主卡
        Row({ space: 12 }) {
          Column({ space: 10 }) {
            Text(`${this.info().term} · 当令`).fontSize(11).fontColor($r('app.color.accent'))
              .backgroundColor($r('app.color.accent_soft'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(10)
            Text(this.info().title)
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
              .width('100%')
            Text(this.info().desc)
              .fontSize(12).lineHeight(19).fontColor($r('app.color.text_secondary')).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.info().chips, (c: string): void => {
                Text(c).fontSize(11).fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.page_background'))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(9)
                  .margin({ right: 6, bottom: 6 })
              }, (c: string): string => c)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text(this.info().key)
            .fontSize(38).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_background'))
        .alignItems(VerticalAlign.Top)

        // 本季好味
        Text('本季好味').fontSize(17).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        Text('精选当季食材菜谱，轻点卡片看完整做法')
          .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')

        ForEach(this.picks(), (r: Recipe): void => {
          Row({ space: 12 }) {
            Column({ space: 2 }) {
              SymbolGlyph($r('sys.symbol.lightbulb_fill'))
                .fontSize(22).fontColor([$r('app.color.accent')])
              Text(this.info().key).fontSize(10).fontColor($r('app.color.text_tertiary'))
            }
            .width(52)
            .height(52)
            .justifyContent(FlexAlign.Center)
            .borderRadius(14)
            .backgroundColor($r('app.color.accent_soft'))

            Column({ space: 4 }) {
              Text(r.name).fontSize(15).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary')).maxLines(1)
              Text(r.tip.length > 0 ? r.tip : `${r.ingredients.length} 种食材`)
                .fontSize(12).fontColor($r('app.color.text_secondary'))
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${r.steps.length} 步 · ${this.difficulty(r.steps.length)}`)
                .fontSize(11).fontColor($r('app.color.accent'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13).fontColor([$r('app.color.text_tertiary')])
          }
          .width('100%')
          .padding(14)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .onClick((): void => {
            AppStorage.setOrCreate<string>('currentRecipeId', r.id);
            router.pushUrl({ url: 'pages/RecipeDetail' });
          })
        }, (r: Recipe): string => `${r.id}_${this.rev}`)

        if (this.picks().length === 0) {
          Text('菜单库还是空的，先去导入或创建菜谱吧')
            .fontSize(13).fontColor($r('app.color.text_tertiary')).width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 20 })
        }

        Column().width('100%').height(20)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    }
  }
}
