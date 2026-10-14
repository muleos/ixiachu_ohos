# I下厨 (IXiaChu)

鸿蒙原生（HarmonyOS NEXT / ArkTS + ArkUI）的菜谱管理与点菜助手应用。

## 功能

- **菜单库**：导入文字版菜谱，自动识别食材、做法、营养价值及热量估算；分类浏览；支持粘贴识别与下厨房在线导入两种方式。
- **点菜**：菜名搜索；按用餐人数随机生成菜单；按热量上限、餐标预算、时令蔬菜、优先消耗库存等需求智能推荐。
- **采购清单**：按点菜情况按人数折算汇总，给出当日基础菜价参考区间（±15%）。
- **食材管理**：拍摄购物小票 OCR 识别入库；按采购日期与气候估算新鲜度，给出剩余可存时间与「尽快食用 / 评估丢弃」建议；支持手动校准；点菜时自动优先消耗剩余食材。

## 原生体验

- 华为官方 HDS 组件：`HdsNavigation` 沉浸式顶栏（滚动渐变模糊光感）+ `HdsTabs` 悬浮胶囊底栏（IMMERSIVE 材质），与酷安原生客户端同款方案。
- 全屏沉浸布局，状态栏内容色随深浅色自动反色。
- 深浅色模式全适配（`resources/dark` 限定词）。

## 构建

1. DevEco Studio 打开工程（compatibleSdkVersion 6.1.0(23)）。
2. 配置签名后 `Build > Build Hap(s)`，或命令行：
   ```bash
   set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk
   hvigorw --mode module -p product=default assembleHap
   ```

## 在线导入（可选）

下厨房在线导入依赖自部署的 [ruter/xiachufang-api](https://github.com/ruter/xiachufang-api) 服务，在「导入菜谱」页填入服务地址即可使用；预置的 16 道精选菜谱数据结构同源（参考 [Sorosliu1029/recipe-crawler](https://github.com/Sorosliu1029/recipe-crawler)）。

## 更新日志

见 [UPDATE_LOG.md](UPDATE_LOG.md)。
