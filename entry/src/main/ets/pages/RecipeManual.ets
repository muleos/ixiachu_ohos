/**
 * 手动创建菜谱（v1.10.0 新增，表单式）：
 * 封面图（选填）→ 菜品名称（必填）→ 一句话风味随笔 → 风味标签（预设+自定义）
 * → 食材清单（增删行）→ 制作步骤（操作说明 + 开火时长 + 防翻车贴士）→ 保存入库。
 * 营养热量走 RecipeParser.estimateNutrition 按食材估算。
 */
import { router, promptAction } from '@kit.ArkUI';
import { picker, fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Recipe, RecipeIngredient, RecipeStep } from '../model/Models';
import { DataStore } from '../service/DataStore';
import { RecipeParser } from '../service/RecipeParser';
import { FrostPage } from '../components/FrostPage';

/** 食材清单行 */
class IngRow {
  name: string = '';
  amount: string = '';
}

/** 制作步骤行 */
class StepRow {
  text: string = '';
  /** 开火时长（分钟，空=选填未填） */
  duration: string = '';
  /** 防翻车贴士（选填） */
  tip: string = '';
}

const PRESET_TAGS: string[] = ['快手', '减脂', '微辣', '硬菜', '家常', '清淡', '下酒', '汤羹'];

@Entry
@Component
struct RecipeManual {
  private scroller: Scroller = new Scroller();
  @State coverPath: string = '';
  @State name: string = '';
  @State note: string = '';
  /** 已选标签（预设点选 + 自定义追加） */
  @State tags: string[] = [];
  @State customTags: string[] = [];
  @State customTagInput: string = '';
  @State ings: IngRow[] = [new IngRow()];
  @State steps: StepRow[] = [new StepRow()];
  @State saving: boolean = false;

  /** 封面图：相册选一张，拷进应用 files 目录（卸载随应用删除） */
  private async pickCover(): Promise<void> {
    try {
      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const result: picker.PhotoSelectResult = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const dir: string = `${ctx.filesDir}/covers`;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
      const dest: string = `${dir}/cover_${Date.now()}.jpg`;
      const src: fileIo.File = await fileIo.open(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(src.fd, dest);
      } finally {
        try {
          fileIo.closeSync(src);
        } catch (e) {
        }
      }
      this.coverPath = dest;
    } catch (e) {
      promptAction.showToast({ message: '封面图选取失败，可跳过直接创建' });
    }
  }

  private toggleTag(t: string): void {
    const i: number = this.tags.indexOf(t);
    if (i >= 0) {
      this.tags = this.tags.filter((x: string): boolean => x !== t);
    } else {
      this.tags = this.tags.concat([t]);
    }
  }

  private addCustomTag(): void {
    const t: string = this.customTagInput.trim();
    if (t.length === 0) {
      return;
    }
    if (this.tags.indexOf(t) < 0 && this.customTags.indexOf(t) < 0) {
      this.customTags = this.customTags.concat([t]);
    }
    if (this.tags.indexOf(t) < 0) {
      this.tags = this.tags.concat([t]);
    }
    this.customTagInput = '';
  }

  private addIng(): void {
    this.ings = this.ings.concat([new IngRow()]);
  }

  private removeIng(i: number): void {
    this.ings = this.ings.filter((_: IngRow, idx: number): boolean => idx !== i);
    if (this.ings.length === 0) {
      this.ings = [new IngRow()];
    }
  }

  private addStep(): void {
    this.steps = this.steps.concat([new StepRow()]);
  }

  private removeStep(i: number): void {
    this.steps = this.steps.filter((_: StepRow, idx: number): boolean => idx !== i);
    if (this.steps.length === 0) {
      this.steps = [new StepRow()];
    }
  }

  private save(): void {
    const n: string = this.name.trim();
    if (n.length === 0) {
      promptAction.showToast({ message: '请填写菜品名称' });
      return;
    }
    const recipe: Recipe = new Recipe();
    recipe.id = `m${Date.now()}`;
    recipe.name = n;
    recipe.servings = 2;
    recipe.source = '手动创建';
    recipe.importTime = Date.now();
    recipe.cover = this.coverPath;
    recipe.tip = this.note.trim();
    recipe.tags = this.tags.slice();

    // 食材行 → 规格化（用量走 ingredientFromRaw 解析，纯名称兜底「适量」）
    for (const row of this.ings) {
      const nm: string = row.name.trim();
      if (nm.length === 0) {
        continue;
      }
      const amt: string = row.amount.trim();
      const parsed = amt.length > 0 ? RecipeParser.ingredientFromRaw(`${nm} ${amt}`) : null;
      if (parsed !== null) {
        recipe.ingredients.push(parsed);
      } else {
        // 纯名称或解析失败：按「适量」兜底，保证行不丢
        recipe.ingredients.push(new RecipeIngredient(nm, 0, '', amt.length > 0 ? `${nm} ${amt}` : nm));
      }
    }
    // 步骤：说明 +（约 X 分钟）+ 贴士 合并为步骤文本
    let idx: number = 1;
    for (const row of this.steps) {
      const t: string = row.text.trim();
      if (t.length === 0) {
        continue;
      }
      let full: string = t;
      const d: string = row.duration.trim();
      if (d.length > 0) {
        full += `（约${d}分钟）`;
      }
      const tp: string = row.tip.trim();
      if (tp.length > 0) {
        full += `。贴士：${tp}`;
      }
      recipe.steps.push(new RecipeStep(idx, full));
      idx++;
    }
    if (recipe.ingredients.length === 0 && recipe.steps.length === 0) {
      promptAction.showToast({ message: '至少填写食材或制作步骤之一' });
      return;
    }
    recipe.nutrition = RecipeParser.estimateNutrition(recipe.ingredients, recipe.servings);
    if (recipe.tags.length === 0) {
      recipe.tags = RecipeParser.deriveTags(recipe);
    }
    DataStore.saveRecipe(recipe);
    promptAction.showToast({
      message: `已入库：${recipe.name}（${recipe.ingredients.length}种食材 / ${recipe.steps.length}步）`
    });
    router.back();
  }

  build() {
    Stack() {
    FrostPage({
      title: '制作菜单',
      subtitle: '记录专属于您的私家美味',
      scroller: this.scroller
    }) {
      Column({ space: 14 }) {
        // 封面图（选填）
        if (this.coverPath.length === 0) {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.camera')).fontSize(30).fontColor([$r('app.color.accent')])
            Text('添加菜品封面图').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text('留存一道菜的首个视觉风味（选填）').fontSize(11).fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .padding({ top: 28, bottom: 28 })
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .onClick((): void => {
            this.pickCover();
          })
        } else {
          Stack({ alignContent: Alignment.TopEnd }) {
            Image(`file://${this.coverPath}`)
              .width('100%')
              .height(180)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
              .backgroundColor($r('app.color.card_background'))
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(22)
              .fontColor([$r('app.color.text_secondary')])
              .margin({ top: 8, right: 8 })
              .onClick((): void => {
                this.coverPath = '';
              })
          }
          .width('100%')
        }

        // 名称与风味随笔
        Column({ space: 10 }) {
          TextInput({ placeholder: '菜品名称（必填，如：红烧牛腩）', text: this.name })
            .width('100%')
            .height(44).fontSize(15)
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .onChange((v: string): void => {
              this.name = v;
            })
          Divider().color($r('app.color.divider')).strokeWidth(0.5)
          TextInput({ placeholder: '一句话风味随笔（选填，如：浓郁酱香，拌饭一绝）', text: this.note })
            .width('100%')
            .height(44).fontSize(14)
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .fontColor($r('app.color.text_secondary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .onChange((v: string): void => {
              this.note = v;
            })
        }
        .width('100%').padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // 风味标签
        Column({ space: 12 }) {
          Row() {
            Text('风味标签').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            Blank()
            Text('点选或自定义').fontSize(11).fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(PRESET_TAGS.concat(this.customTags), (t: string): void => {
              Text(t)
                .fontSize(13)
                .fontColor(this.tags.indexOf(t) >= 0 ? Color.White : $r('app.color.text_secondary'))
                .backgroundColor(this.tags.indexOf(t) >= 0 ? $r('app.color.accent') : $r('app.color.page_background'))
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .borderRadius(16)
                .margin({ right: 10, bottom: 10 })
                .onClick((): void => {
                  this.toggleTag(t);
                })
            }, (t: string): string => t)
          }
          .width('100%')
          Row({ space: 10 }) {
            TextInput({ placeholder: '自定义新标签', text: this.customTagInput })
              .layoutWeight(1)
              .height(40).fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(20)
              .onChange((v: string): void => {
                this.customTagInput = v;
              })
              .onSubmit((): void => {
                this.addCustomTag();
              })
            Button('添加')
              .height(40).borderRadius(20)
              .padding({ left: 18, right: 18 })
              .backgroundColor($r('app.color.accent'))
              .fontColor(Color.White)
              .fontSize(14)
              .onClick((): void => {
                this.addCustomTag();
              })
          }
          .width('100%')
        }
        .width('100%').padding(16).borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // 食材清单
        Column({ space: 12 }) {
          Row() {
            Text('食材清单').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            Blank()
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.plus')).fontSize(14).fontColor([$r('app.color.accent')])
              Text('添加食材').fontSize(13).fontColor($r('app.color.accent'))
            }
            .onClick((): void => {
              this.addIng();
            })
          }
          .width('100%')
          ForEach(this.ings, (row: IngRow, i: number): void => {
            Row({ space: 10 }) {
              TextInput({ placeholder: '食材（如：牛腩）', text: row.name })
                .layoutWeight(1)
                .height(40).fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .backgroundColor($r('app.color.page_background'))
                .borderRadius(10)
                .onChange((v: string): void => {
                  (this.ings[i] as IngRow).name = v;
                })
              TextInput({ placeholder: '用量（如：300克）', text: row.amount })
                .layoutWeight(1)
                .height(40).fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .backgroundColor($r('app.color.page_background'))
                .borderRadius(10)
                .onChange((v: string): void => {
                  (this.ings[i] as IngRow).amount = v;
                })
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(16)
                .fontColor([$r('app.color.text_tertiary')])
                .onClick((): void => {
                  this.removeIng(i);
                })
            }
            .width('100%')
          }, (row: IngRow, i: number): string => `ing_${i}`)
        }
        .width('100%').padding(16).borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .alignItems(HorizontalAlign.Start)

        // 制作步骤
        Column({ space: 14 }) {
          Row() {
            Text('制作步骤').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            Blank()
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.plus')).fontSize(14).fontColor([$r('app.color.accent')])
              Text('添加步骤').fontSize(13).fontColor($r('app.color.accent'))
            }
            .onClick((): void => {
              this.addStep();
            })
          }
          .width('100%')
          ForEach(this.steps, (row: StepRow, i: number): void => {
            Column({ space: 10 }) {
              Row() {
                Text(`第 ${i + 1} 步`).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.accent'))
                Blank()
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(15)
                  .fontColor([$r('app.color.text_tertiary')])
                  .onClick((): void => {
                    this.removeStep(i);
                  })
              }
              .width('100%')
              TextArea({ placeholder: '操作说明（例如：大火热锅，下入姜片与牛腩翻炒出香味）', text: row.text })
                .width('100%')
                .height(84)
                .padding(12)
                .borderRadius(12)
                .backgroundColor($r('app.color.page_background'))
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .onChange((v: string): void => {
                  (this.steps[i] as StepRow).text = v;
                })
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.clock')).fontSize(14).fontColor([$r('app.color.text_tertiary')])
                TextInput({ placeholder: '开火时长（选填，如：15）', text: row.duration })
                  .layoutWeight(1)
                  .height(38).fontSize(13).type(InputType.NUMBER_DECIMAL)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .backgroundColor($r('app.color.page_background'))
                  .borderRadius(10)
                  .onChange((v: string): void => {
                    (this.steps[i] as StepRow).duration = v;
                  })
                Text('分钟').fontSize(13).fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              TextInput({ placeholder: '防翻车贴士（选填，如：此步骤切记小火）', text: row.tip })
                .width('100%')
                .height(38).fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .backgroundColor($r('app.color.page_background'))
                .borderRadius(10)
                .onChange((v: string): void => {
                  (this.steps[i] as StepRow).tip = v;
                })
            }
            .width('100%').padding(14).borderRadius(14)
            .backgroundColor($r('app.color.page_background'))
          }, (row: StepRow, i: number): string => `step_${i}`)
        }
        .width('100%').padding(16).borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .alignItems(HorizontalAlign.Start)

        // 保存
        Button('保存菜谱')
          .width('100%')
          .height(48).borderRadius(24)
          .backgroundColor($r('app.color.accent'))
          .fontColor(Color.White)
          .fontSize(16).fontWeight(FontWeight.Medium)
          .onClick((): void => {
            this.save();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    }
  }
}
