/**
 * 笔记存储（v1.12.0）：做菜点滴帖子（文字/图片/视频），全部本地保存。
 * 独立 preferences 实例（notes_db），媒体文件在 filesDir/notes/。
 */
import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';
import { NoteItem } from '../model/Models';

const KEY: string = 'notes_json';

export class NoteStore {
  private static store: preferences.Preferences | null = null;
  private static notes: NoteItem[] = [];

  /** EntryAbility 启动链调用（DataStore.init 之后） */
  static init(ctx: common.UIAbilityContext): void {
    try {
      NoteStore.store = preferences.getPreferencesSync(ctx, { name: 'notes_db' });
      NoteStore.reload();
    } catch (e) {
      NoteStore.notes = [];
    }
  }

  private static reload(): void {
    try {
      const raw: string = (NoteStore.store as preferences.Preferences).getSync(KEY, '') as string;
      const list: NoteItem[] = raw.length === 0 ? [] : JSON.parse(raw) as NoteItem[];
      // 存量归一：字段缺失兜底（cover/images 教训）
      for (const n of list) {
        if (n.mediaPaths === undefined || n.mediaPaths === null) {
          n.mediaPaths = [];
        }
        if (n.videoPath === undefined || n.videoPath === null) {
          n.videoPath = '';
        }
        if (n.text === undefined || n.text === null) {
          n.text = '';
        }
        if (!(n.coverW > 0) || !(n.coverH > 0)) {
          n.coverW = 4;
          n.coverH = 3;
        }
      }
      NoteStore.notes = list.sort((a: NoteItem, b: NoteItem): number => b.time - a.time);
    } catch (e) {
      NoteStore.notes = [];
    }
  }

  static list(): NoteItem[] {
    return NoteStore.notes;
  }

  static get(id: string): NoteItem | null {
    for (const n of NoteStore.notes) {
      if (n.id === id) {
        return n;
      }
    }
    return null;
  }

  static save(n: NoteItem): void {
    const i: number = NoteStore.notes.findIndex((x: NoteItem): boolean => x.id === n.id);
    if (i >= 0) {
      NoteStore.notes[i] = n;
    } else {
      NoteStore.notes.unshift(n);
    }
    NoteStore.notes.sort((a: NoteItem, b: NoteItem): number => b.time - a.time);
    NoteStore.persist();
  }

  static remove(id: string): void {
    NoteStore.notes = NoteStore.notes.filter((x: NoteItem): boolean => x.id !== id);
    NoteStore.persist();
  }

  private static persist(): void {
    try {
      (NoteStore.store as preferences.Preferences).putSync(KEY, JSON.stringify(NoteStore.notes));
      (NoteStore.store as preferences.Preferences).flush();
    } catch (e) {
    }
    // 广播刷新（瀑布流 @Watch）
    AppStorage.setOrCreate<number>('notesRev', Date.now());
  }
}
