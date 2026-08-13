# IC-20260812-024 自验报告

## 一、结论

本卡只补充 XCTest、自验脚本及 CI 调用，不修改产品源码、SPEC 或 `Reports/TRACEABILITY-S3-S5.md`，也不新增 XCUITest。静态测试方法总数由 179 增至 189；9 条范围内条款均有编号专项方法，C34-093 按要求拆成两个方法，因此共新增 10 个测试。阻塞清单为空。

| 统计项 | 数量或结果 |
|---|---:|
| 范围内条款 | 9 |
| 新增 XCTest | 10 |
| XCTest 总数 | 189 |
| 阻塞清单 | 无 |

## 二、新增测试明细

| 条款 | XCTest 方法 | 直接断言 |
|---|---|---|
| C34-093 | `testC34_093GeneratedSubmissionIdentifiersAreUnique` | 默认生成器产生 256 个可解析 UUID，逐个插入唯一集合且无重复。 |
| C34-093 | `testC34_093SubmissionIdentifierEndsWhenTargetS5Receives` | 提交标识从 S3 冻结值完整交接至目标 S5 初始持久化状态。 |
| C34-094 | `testC34_094AssetIdentifiersEndWhenTargetS5Receives` | 有序资产标识集合完整交接至目标 S5。 |
| C34-095 | `testC34_095AssetCountEndsWhenTargetS5Receives` | 资产数量完整交接至目标 S5。 |
| C34-096 | `testC34_096KnownTotalBytesEndsWhenTargetS5Receives` | 已知总字节数完整交接至目标 S5。 |
| C34-097 | `testC34_097UnavailableCountEndsWhenTargetS5Receives` | `unavailableCount` 完整交接至目标 S5。 |
| C34-098 | `testC34_098VolumeDisplayModeEndsWhenTargetS5Receives` | 体积显示模式完整交接至目标 S5。 |
| C34-099 | `testC34_099FavoriteAssetIdentifiersEndWhenTargetS5Receives` | 收藏资产标识集合完整交接至目标 S5。 |
| C34-100 | `testC34_100FrozenTimeEndsWhenTargetS5Receives` | 冻结时间完整交接至目标 S5。 |
| C34-101 | `testC34_101TwoFirstFreezeGuardsDefineCurrentCompletenessBoundary` | 空集合被第一条守卫拒绝，扫描未完成被第二条守卫拒绝；非空且完成的两种结论及混合集合均可冻结。 |

八个字段测试共用真实的 S3 冻结、S4 成功终态和 `S5StateMachine.enter` 路径，但每个条款保留独立方法与独立字段断言。这里的“生命周期终点”按交接边界解释：冻结值必须保持不变，直到目标 S5 在入口持久化时接收；它不表示 S5 接收后必须擦除该值。

## 三、断言边界说明

### C34-093

有限 XCTest 不能从数学上穷尽证明全局永不碰撞。本卡没有把有限样本改写成绝对证明：产品默认生成契约仍是 `UUID().uuidString`，专项测试验证生成值可解析为 UUID，并对 256 次独立默认生成做零碰撞检查；同一提交标识的重复使用仍由既有 S4 唯一登记测试覆盖。

### C34-101

本卡按题卡要求改断“当前两条首次冻结资格守卫的完备性边界”，不声称穷尽所有未来代码或无限输入。边界分为三组：`n = 0`、`n ≥ 1` 但存在未完成项、`n ≥ 1` 且全部完成；前两组分别由规格两条守卫拒绝，第三组覆盖 `knownBytes`、`unavailable` 与二者混合后均成功冻结。

`alreadyFrozen` 是首次成功冻结之后防止重复冻结的提交后守卫，不是对当前 `D` 的首次冻结资格校验，因此从 C34-101 的“两条冻结校验”完备性断言中排除；其行为继续由既有 `testSecondFreezeIsRejectedAndOriginalSnapshotIsKept` 覆盖。构造器前置条件与快照字段不变量也不被改写成第三类资格守卫。

## 四、范围与保护证据

| 检查项 | 证据 |
|---|---|
| 任务开始 HEAD | `5ed266c23cfc657c616fffa54426b904e2824b36` |
| 产品源码 Git blob | 专项脚本逐文件比较任务基线、当前 HEAD 与工作树的 `PhotoCleanupMVE/` blob。 |
| 输入 SPEC | `SPEC-S3-S4-20260812.v6.md`；SHA-256：`BF52BBE87692A253BDA9C2AC8B55712C76AB453E3AAF6C5D286BC15835E04C7D`。 |
| 追踪矩阵 | `Reports/TRACEABILITY-S3-S5.md`；任务基线 Git blob：`7774caca2f638f86a0b70e4f1e1168aa873544fa`。 |
| XCUITest | 工程只允许 `application` 与 `bundle.unit-test` 两种 product type，共两个 target；共享方案不得出现 UI 测试引用。 |
| 产品代码 | 未修改。 |
| SPEC 与追踪矩阵 | 未修改。 |
| 外部依赖 | 未下载或安装；CI 现有外部 Action 仍锁定完整提交哈希。 |

## 五、自验脚本

CI 回填前或 CI 内运行：

```powershell
& ./Scripts/verify-IC-20260812-024.ps1 -允许待回填CI
```

CI 回填后最终只读运行：

```powershell
& ./Scripts/verify-IC-20260812-024.ps1
```

脚本会调用通用结构门禁，并机械核对基线 179 项、当前 189 项、10 个指定方法、各条款编号命中数、C34-093/C34-101 关键断言、产品 blob、SPEC 摘要、追踪矩阵 blob、target 类型、改动白名单和 CI 配置。

## 六、执行结果与最终证据

| 项目 | 结果 |
|---|---|
| Windows 静态自验 | 通过；专项脚本退出码 0，共执行 112 项检查；通用结构与硬编码门禁通过。 |
| macOS 全量 XCTest | CI 结果待本次推送回填 |
| Release 构建 | CI 结果待本次推送回填 |
| 受验提交 | 待首次提交 |
| CI 编号 | CI 结果待本次推送回填 |
| CI 链接 | CI 结果待本次推送回填 |
| 最终提交哈希 | 本报告自身为末次提交；其 Git 对象哈希在提交完成后由最终回传给出。 |

最终流程只运行一次完整 CI 矩阵。CI 成功后仅回填本节并以 `[skip ci]` 提交报告，不重跑矩阵。
