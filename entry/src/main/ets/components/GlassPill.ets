/**
 * GlassPill —— 官方沉浸光感胶囊按钮（v1.11.1，酷安/鸿蒙官方样式）：
 * 白玻璃底 + BlurStyle.Regular 真模糊 + 细描边，accent 内容色。
 * 用于页面顶部操作区（识别/导入/手动录入/拍小票入库等）。
 */
@Component
export struct GlassPill {
  @StorageProp('isDarkMode') isDark: boolean = false;
  icon: Resource = $r('sys.symbol.picture');
  label: string = '';
  /** 图标专用小胶囊宽度（label 为空时生效，0=自适应）；命名避开基类 width 属性 */
  fixedWidth: number = 0;
  onTap: () => void = (): void => {
  };

  build() {
    Button() {
      Row({ space: 6 }) {
        SymbolGlyph(this.icon)
          .fontSize(18)
          .fontColor([$r('app.color.accent')])
        if (this.label.length > 0) {
          Text(this.label).fontSize(14).fontColor($r('app.color.accent'))
        }
      }
    }
    .height(40)
    .borderRadius(20)
    .width(this.fixedWidth > 0 ? this.fixedWidth : 'auto')
    .padding(this.fixedWidth > 0 ? 0 : { left: 14, right: 14 })
    .backgroundColor(this.isDark ? '#3DFFFFFF' : '#66FFFFFF')
    .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
    .border({ width: 0.5, color: this.isDark ? '#33FFFFFF' : '#8CFFFFFF' })
    .onClick((): void => {
      this.onTap();
    })
  }
}
