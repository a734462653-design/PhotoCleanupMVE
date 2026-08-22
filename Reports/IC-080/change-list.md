# IC-080 变更清单

`main` 自 `8acf43d05d6fa0d7a74024baf78b29d775e1d820` 以 `git merge --ff-only origin/feature/ic-079-fast-paging-window` 快进至 `7a11a182460ca34eb542414c2aefa1c2bf6f3205`。无代码改动、无新 merge 提交。本卡自身只追加 `Reports/IC-080/` 两个文件的一个 docs 提交。

## 进入 `main` 的提交（`git log --format='%h %s' 8acf43d..7a11a18`，实测 31 个；卡内"预期 29"为估计值）

| 卡 | SHA | 说明 |
|---|---|---|
| IC-074 | `9cbe77a` | refactor: S2ResolvedParameters 移除四项废止参数，1x 横向拖动结束不再由状态机切页 |
| IC-074 | `7a8a8fa` | refactor: 参数层按 SPEC-S2 v15 对齐，删除 15 个废止参数并引入双维度登记表 |
| IC-074 | `11b07f3` | docs: 完成 IC-074 参数层对齐自验与变更清单 |
| IC-075 | `681cae9` | feat: 顶部信息区按 v15 决策 30 精简为返回、序号、确认页入口三件 |
| IC-075 | `f3b5d2d` | feat: 确认页入口徽标仅在会话待删总数大于 0 时显示，为 0 时入口禁用 |
| IC-075 | `1d0551a` | fix: 确认页入口无障碍文案改为显式键引用，使字符串目录扫描能识别 |
| IC-075 | `4148654` | feat: 横栏缩略图右上角叠加待删标记，尺寸由定案参数 bottomStripMarkSize 决定 |
| IC-075 | `d426d5c` | feat: 主图右上角待删标记浮层，已标记再上滑时按 markPulseDurationMilliseconds 脉冲一次 |
| IC-075 | `d6de321` | refactor: 移除相册角标与 G(a)，加入相册后从 D 移除静默完成 |
| IC-075 | `c99b0da` | docs: 完成 IC-075 顶部信息区、徽标与待删标记自验与变更清单 |
| IC-076 | `f789473` | feat: 最近相册 H 的 UserDefaults 持久化存储（S2RecentAlbumStore），注入式以便测试用内存实现 |
| IC-076 | `e783b7d` | feat: 操作条三按钮 in-flight 标志、相簿选择选中→写入中→结果三段流程、失败反馈事件与 H 变化回调，删除未定项 11 占位 |
| IC-076 | `dcb5d84` | fix: 状态机注释改用「」引号，使字符串目录扫描不误判为字面量 |
| IC-076 | `50d4e2c` | feat: 操作条按钮绑定 in-flight 禁用态，写入失败底部 toast（feedbackToastDurationMilliseconds=2000），sheet 写入中禁用列表并提供相簿列表视图 |
| IC-076 | `eb7a43b` | feat: PhotoKit 写入服务（收藏切换、加入相册含写入前已包含判定、用户相册列表、相册存在性校验），协调器接线三个按钮回调并在 enterS2 校验持久化 H |
| IC-076 | `10ff08b` | docs: 完成 IC-076 操作条接线自验与变更清单 |
| IC-077 | `890b5cf` | feat: 图片请求允许网络访问并以 opportunistic 交付，结果区分降质/最终/失败/取消/失效；degradedPreviewPolicy 出厂改为 display，两项请求策略登记为 decided |
| IC-077 | `8035ffe` | feat: 主图加载中复用语义色视口背景，降质预览先显示并由最终图原位替换，失败与资产失效显示 photo.badge.exclamationmark 与一行占位文案，取消不计失败 |
| IC-077 | `7d3b3ef` | feat: 双击到达目标倍率时请求一次图像（与捏合结束共用请求信号），并以假策略断言捏合/双击/翻页/视口变化的请求节流 |
| IC-077 | `14c8c80` | test: 交接校验失败（D ⊄ A）时 enterS2 返回 false 且停留 S1、会话对象不变的协调器断言 |
| IC-077 | `03bd062` | test: G127 请求节流断言改用已验证的原生分页控制器夹具，并按 S2View 页窗口规则构造页列表 |
| IC-077 | `253212e` | docs: 完成 IC-077 图片加载态自验与变更清单 |
| IC-078 | `aabd2e9` | feat(s2): pinchMaxScale 改为按资产动态取值的纯函数，参数替换为 pinchMaxScaleFloor=4 / pinchMaxScaleCeiling=10（R1） |
| IC-078 | `2de49ce` | feat(s2): 状态机按当前资产钳制倍率——登记资产缩放几何并暴露 pinchMaxScale(for:)（R2） |
| IC-078 | `01c3a20` | feat(s2): 原生页 maximumZoomScale 按资产取值写入，S2View 传入资产缩放几何（R3） |
| IC-078 | `503380c` | test: G134 使用 S2State.visibleOneXIdle（R2 编译修正） |
| IC-078 | `5691767` | docs: 完成 IC-078 动态缩放上限自验与变更清单（R4 冲突停下报告） |
| IC-079 | `241cb6f` | diag(s2): 诊断录制新增场景 D 快速连续翻页——页窗口逐帧字段与页生命周期/偏移写入/翻页事件；夹具探针（R1） |
| IC-079 | `40b51c4` | fix(s2): 分页控制器按滚动位置自主创建页（页内容提供者 + 保留半径 ±2），滚停时偏移已在结算位不再二次写入（R2） |
| IC-079 | `42be541` | test: G127 按 IC-079 保留半径 ±2 再翻一页后断言离开窗口的请求取消（R2 测试适配） |
| IC-079 | `7a11a18` | docs: 完成 IC-079 快速翻页页窗口自验与变更清单 |
| IC-080 | （本卡 docs 提交，SHA 见自验报告） | docs: 完成 IC-080 合并自验与变更清单 |

## 文件变化（`8acf43d..7a11a18`，`git merge` 输出）

28 个文件，+5013 / −664。产品：`project.pbxproj`、`App/CleanupCoordinator.swift`、`App/PhotoCleanupMVEApp.swift`、`Core/S2StateMachine.swift`、`Features/S2/S2Calibration.swift`、`Features/S2/S2NativePhotoPager.swift`、`Features/S2/S2TemporaryPhotoImageStrategy.swift`、`Features/S2/S2View.swift`、`Localizable.xcstrings`、新增 `Services/PhotoAssetActionService.swift`、`Services/S2RecentAlbumStore.swift`。测试：`S2CalibrationHarnessTests.swift`、`S2StateMachineTests.swift`、新增 `S2ActionBarWiringTests.swift`、`S2ImageLoadingStateTests.swift`。报告：`Reports/IC-068/export-format.md`（追加）、`Reports/IC-074～079/` 各两文件。

## 未变更

六个 feature 分支远端指针（`11b07f3`、`c99b0da`、`10ff08b`、`253212e`、`5691767`、`7a11a18`）与快进前一致；`probe/ic-067-screenshot-subtype` 独有提交进入 `main` 0 个；SPEC、Decision_log、`CLAUDE.md`、`Scripts/`、`ci.yml`、worktree 未动。
