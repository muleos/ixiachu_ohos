/** 2x2 桌面卡片：今日菜单前 3 道 + 人数；点击落「点菜」页 */
@Entry
@Component
struct MenuSmallCard {
  @LocalStorageProp('dishes') dishes: string[] = [];
  @LocalStorageProp('people') people: number = 0;
  @LocalStorageProp('hasMenu') hasMenu: boolean = false;
  @LocalStorageProp('date') date: string = '';

  build() {
    Column({ space: 6 }) {
      Row() {
        Text('今日菜单')
          .fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(this.date)
          .fontSize(10)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')

      if (this.hasMenu) {
        Column({ space: 4 }) {
          ForEach(this.dishes, (n: string, i: number): void => {
            Row({ space: 6 }) {
              Text(`${i + 1}`)
                .fontSize(10).fontColor(Color.White)
                .backgroundColor($r('sys.color.brand'))
                .width(14).height(14).borderRadius(7)
                .textAlign(TextAlign.Center)
              Text(n)
                .fontSize(13)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
          }, (n: string): string => n)
        }
        .layoutWeight(1)
        .width('100%')

        Text(this.people > 0 ? `${this.people} 人 · 点击查看` : '点击查看')
          .fontSize(10)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      } else {
        Column({ space: 6 }) {
          Text('还没安排菜单')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
          Text('点击去点菜 →')
            .fontSize(11)
            .fontColor($r('sys.color.brand'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .onClick((): void => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { launchTab: 1 }
      });
    })
  }
}
