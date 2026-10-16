/** 2x4 桌面卡片：今日菜单（3 道+人数）+ 临期食材 Top3（红标）；点菜单区落「点菜」、临期区落「食材管理」 */
@Entry
@Component
struct MenuLargeCard {
  @LocalStorageProp('dishes') dishes: string[] = [];
  @LocalStorageProp('people') people: number = 0;
  @LocalStorageProp('hasMenu') hasMenu: boolean = false;
  @LocalStorageProp('urgent') urgent: string[] = [];
  @LocalStorageProp('urgentCount') urgentCount: number = 0;
  @LocalStorageProp('date') date: string = '';

  build() {
    Column({ space: 10 }) {
      // 菜单区（点击 → 点菜页）
      Column({ space: 6 }) {
        Row() {
          Text('今日菜单')
            .fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Blank()
          if (this.people > 0) {
            Text(`${this.people} 人`)
              .fontSize(10).fontColor(Color.White)
              .backgroundColor($r('sys.color.brand'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(9)
          }
          Text(this.date)
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ left: 8 })
        }
        .width('100%')

        if (this.hasMenu) {
          ForEach(this.dishes, (n: string, i: number): void => {
            Row({ space: 8 }) {
              Text(`${i + 1}`)
                .fontSize(11).fontColor(Color.White)
                .backgroundColor($r('sys.color.brand'))
                .width(16).height(16).borderRadius(8)
                .textAlign(TextAlign.Center)
              Text(n)
                .fontSize(14)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
          }, (n: string): string => n)
        } else {
          Text('还没安排菜单，点击去点菜 →')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
        }
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor($r('sys.color.comp_background_regular'))
      .onClick((): void => {
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: { launchTab: 1 }
        });
      })

      // 临期区（点击 → 食材管理页）
      Column({ space: 6 }) {
        Row() {
          Text('临期提醒')
            .fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Blank()
          if (this.urgentCount > 0) {
            Text(`${this.urgentCount} 项建议尽快食用`)
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor('#F8284C')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(9)
          } else {
            Text('冰箱状态良好')
              .fontSize(10)
              .fontColor($r('sys.color.font_tertiary'))
          }
        }
        .width('100%')

        if (this.urgentCount > 0) {
          ForEach(this.urgent, (n: string, i: number): void => {
            Row({ space: 6 }) {
              Circle({ width: 5, height: 5 }).fill('#F8284C')
              Text(n)
                .fontSize(13)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
          }, (n: string): string => n)
        } else {
          Text('暂无临期食材')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
        }
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor($r('sys.color.comp_background_regular'))
      .onClick((): void => {
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: { launchTab: 3 }
        });
      })
    }
    .width('100%')
    .height('100%')
    .padding(10)
  }
}
