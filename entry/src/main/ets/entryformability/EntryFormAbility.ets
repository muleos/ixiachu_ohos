/**
 * 桌面卡片 Form 扩展：
 * onAddForm 记录 formId 并返回初始数据；onUpdateForm 定时/定点刷新；
 * onRemoveForm 清理 formId。数据统一由 WidgetSync 组装。
 */
import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WidgetSync } from '../service/WidgetSync';

const DOMAIN: number = 0x1C9;
const TAG: string = 'EntryFormAbility';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = (want.parameters?.['ohos.extra.param.key.form_identity'] ?? '') as string;
    WidgetSync.addFormId(formId);
    hilog.info(DOMAIN, TAG, 'onAddForm %{public}s', formId);
    return WidgetSync.buildBindingData();
  }

  onUpdateForm(formId: string): void {
    formProvider.updateForm(formId, WidgetSync.buildBindingData()).catch((err: Error): void => {
      hilog.warn(DOMAIN, TAG, 'updateForm failed: %{public}s', err.message);
    });
  }

  onRemoveForm(formId: string): void {
    WidgetSync.removeFormId(formId);
    hilog.info(DOMAIN, TAG, 'onRemoveForm %{public}s', formId);
  }
}
