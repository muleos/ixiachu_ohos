/**
 * 拼音工具（v1.12.7）：i18n 音译器取中文首字母（菜单库排序/筛选）。
 * Any-Latin + Latin-Ascii + Any-Lower → '西红柿' → 'xihongshi' → 'X'。
 */
import { i18n } from '@kit.LocalizationKit';

let trans: i18n.Transliterator | null = null;

export class PinyinUtil {
  /** 首字母（A-Z；无法解析归 '#'） */
  static firstLetter(name: string): string {
    if (name.length === 0) {
      return '#';
    }
    try {
      if (trans === null) {
        trans = i18n.Transliterator.getInstance('Any-Latin; Latin-Ascii; Any-Lower');
      }
      const py: string = trans.transform(name.charAt(0));
      for (let i = 0; i < py.length; i++) {
        const ch: string = py.charAt(i);
        if (ch >= 'a' && ch <= 'z') {
          return ch.toUpperCase();
        }
      }
    } catch (e) {
      // 音译器不可用时归 #
    }
    return '#';
  }
}
