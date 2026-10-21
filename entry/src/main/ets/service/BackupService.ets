/**
 * 本地备份/恢复（v1.13.0）：菜单库（菜谱）/ 笔记（含图片视频）/ 采购清单 / 食材库存。
 * 单个 JSON 文件（媒体 base64 内联），经系统文档选择器保存/选取，全部本地、不上传。
 */
import { picker, fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { NoteItem } from '../model/Models';
import { DataStore } from './DataStore';
import { NoteStore } from './NoteStore';

interface BackupPayload {
  app: string;
  version: number;
  exportedAt: string;
  recipes: object[];
  stock: object[];
  shopping: object[];
  notes: NoteItem[];
  media: Record<string, string>;
}

export class BackupService {
  /** 导出：弹系统保存对话框，返回保存的 uri（用户取消返回空串） */
  static async exportBackup(ctx: common.UIAbilityContext): Promise<string> {
    const media: Record<string, string> = {};
    const b64: util.Base64Helper = new util.Base64Helper();
    const collect = (p: string): void => {
      if (p.length === 0 || !p.startsWith('/')) {
        return;
      }
      const key: string = BackupService.baseName(p);
      if (key.length === 0 || media[key] !== undefined) {
        return;
      }
      try {
        const f: fileIo.File = fileIo.openSync(p, fileIo.OpenMode.READ_ONLY);
        try {
          const size: number = fileIo.statSync(p).size;
          const buf: ArrayBuffer = new ArrayBuffer(size);
          fileIo.readSync(f.fd, buf);
          media[key] = b64.encodeToStringSync(new Uint8Array(buf));
        } finally {
          fileIo.closeSync(f);
        }
      } catch (e) {
        // 单个媒体读取失败：跳过该文件
      }
    };
    for (const n of NoteStore.list()) {
      for (const p of n.mediaPaths) {
        collect(p);
      }
      collect(n.videoPath);
    }

    const payload: BackupPayload = {
      app: 'ixiachu-backup',
      version: 1,
      exportedAt: new Date().toISOString(),
      recipes: DataStore.getRecipes() as object[],
      stock: DataStore.getStock() as object[],
      shopping: DataStore.getShopping() as object[],
      notes: NoteStore.list(),
      media: media
    };
    const json: string = JSON.stringify(payload);

    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
    const opts: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    const d: Date = new Date();
    const p2 = (v: number): string => v < 10 ? `0${v}` : `${v}`;
    opts.newFileNames = [`ixiachu_backup_${d.getFullYear()}${p2(d.getMonth() + 1)}${p2(d.getDate())}.json`];
    const uris: string[] = await docPicker.save(opts);
    if (uris.length === 0) {
      return '';
    }
    const f: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(f.fd, json);
    } finally {
      fileIo.closeSync(f);
    }
    return uris[0];
  }

  /** 恢复：弹系统选取对话框，覆盖导入四类数据，返回摘要（用户取消返回空串） */
  static async importBackup(ctx: common.UIAbilityContext): Promise<string> {
    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
    const opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    opts.maxSelectNumber = 1;
    opts.fileSuffixFilters = ['.json'];
    const uris: string[] = await docPicker.select(opts);
    if (uris.length === 0) {
      return '';
    }
    // 读文件
    const f: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
    let json: string = '';
    try {
      const size: number = fileIo.statSync(uris[0]).size;
      const buf: ArrayBuffer = new ArrayBuffer(size);
      fileIo.readSync(f.fd, buf);
      json = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
    } finally {
      fileIo.closeSync(f);
    }
    const payload: BackupPayload = JSON.parse(json) as BackupPayload;
    if (payload.app !== 'ixiachu-backup') {
      throw new Error('不是 I下厨 的备份文件');
    }

    // 媒体落盘（notes 目录），并回填笔记路径
    const b64: util.Base64Helper = new util.Base64Helper();
    const dir: string = `${ctx.filesDir}/notes`;
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
    } catch (e) {
    }
    const fixed: NoteItem[] = [];
    for (const n of payload.notes ?? []) {
      const mapped: string[] = [];
      for (const p of n.mediaPaths ?? []) {
        const key: string = BackupService.baseName(p);
        const data: string | undefined = payload.media?.[key];
        if (data !== undefined) {
          const dest: string = `${dir}/r_${n.id}_${key}`;
          try {
            const out: fileIo.File =
              fileIo.openSync(dest, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
            try {
              fileIo.writeSync(out.fd, b64.decodeSync(data).buffer as ArrayBuffer);
            } finally {
              fileIo.closeSync(out);
            }
            mapped.push(dest);
          } catch (e) {
            // 单个媒体写失败：跳过
          }
        }
      }
      n.mediaPaths = mapped;
      if ((n.videoPath ?? '').length > 0) {
        const vKey: string = BackupService.baseName(n.videoPath);
        const vData: string | undefined = payload.media?.[vKey];
        if (vData !== undefined) {
          const vDest: string = `${dir}/r_${n.id}_${vKey}`;
          try {
            const out: fileIo.File =
              fileIo.openSync(vDest, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
            try {
              fileIo.writeSync(out.fd, b64.decodeSync(vData).buffer as ArrayBuffer);
            } finally {
              fileIo.closeSync(out);
            }
            n.videoPath = vDest;
          } catch (e) {
            n.videoPath = '';
          }
        } else {
          n.videoPath = '';
        }
      }
      fixed.push(n);
    }

    // 应用四类数据（persist 内部会广播 dataRev / notesRev）
    DataStore.setRecipes((payload.recipes ?? []) as never[]);
    DataStore.setStock((payload.stock ?? []) as never[]);
    DataStore.setShopping((payload.shopping ?? []) as never[]);
    NoteStore.replaceAll(fixed);

    return `${(payload.recipes ?? []).length} 道菜谱 / ${(payload.stock ?? []).length} 项库存 / ${(payload.shopping ?? []).length} 项采购 / ${fixed.length} 条笔记`;
  }

  private static baseName(p: string): string {
    const parts: string[] = p.split('/');
    return parts.length > 0 ? parts[parts.length - 1] : '';
  }
}
