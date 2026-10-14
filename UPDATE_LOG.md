# I下厨 更新日志

## v1.1.0 (2026-10-15)

### 新增
- **预置菜谱库**：首启自动种入 16 道「下厨房精选」菜谱（红烧肉、清蒸鲈鱼、麻婆豆腐、可乐鸡翅等），字段结构对齐 [Sorosliu1029/recipe-crawler](https://github.com/Sorosliu1029/recipe-crawler) 与 [ruter/xiachufang-api](https://github.com/ruter/xiachufang-api) 的菜谱数据（name / materials / steps / grade / tip）。
- **分类浏览**：菜单库新增分类筛选 chips（家常菜 / 荤菜 / 素菜 / 汤羹 / 主食 / 在线导入）。
- **下厨房在线导入**：粘贴下厨房菜谱链接或 ID，通过自部署 xiachufang-api 服务（`/recipe/{id}/` 接口）拉取完整菜谱入库，服务地址可在导入页配置。
- **菜谱详情增强**：展示下厨房评分、小贴士、分类与来源标签。
- **更新日志**：新增本文件。

### 修复
- HdsNavigation 沉浸式顶栏浮于内容上层，导致页内首行被遮挡无法点击：四个 Tab 首行统一避让「状态栏 + 顶栏(48vp)」。
- 冷启动即处于深色模式时主题状态不生效（mediaquery 初始化缺失）。
- DataStore 异步初始化完成后首屏列表不刷新。
- 食材管理页从小票入库返回后列表不刷新（TabContent 常驻导致 aboutToAppear 不再触发）。

### 变更
- 底栏重构为华为官方 `HdsTabs` 悬浮胶囊底栏（barFloatingStyle / IMMERSIVE 材质），顶栏为 `HdsNavigation`（IMMERSIVE_GRADIENT_BLUR 滚动光感），与酷安原生客户端同款方案。
- compatibleSdkVersion 升级至 6.1.0(23)。
- 全新应用图标（炒锅 + 厨师帽，分层图标适配）。

## v1.0.0 (2026-10-15)

### 首个版本
- **菜单库**：导入文字版菜谱，自动识别食材、做法、营养价值及热量估算。
- **点菜**：菜名搜索 / 按用餐人数随机生成菜单 / 按热量、预算、时令、库存需求推荐。
- **采购清单**：按点菜情况汇总生成，给出当日基础菜价参考区间（±15%）。
- **食材管理**：拍摄购物小票 OCR 识别入库，按采购日期与气候估算新鲜度，剩余可存时间与食用建议，支持手动校准，点菜时优先消耗剩余食材。
- 鸿蒙原生 ArkTS/ArkUI，沉浸式状态栏 + 悬浮玻璃底栏，深浅色全适配。
