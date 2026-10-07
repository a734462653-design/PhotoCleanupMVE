# IC-186 变更清单

任务卡：`Tasks/IC-20261007-186-range-volume-interface.md`（S1 重设计批第一张——范围体积接口：A Core 体积口径新文件；B 扫描服务只读读口 `assetByteCountTable()`；C 三条新测试 + pbx 登记；不做界面、不做接线）。
基线：`main` = `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`。分支：`feature/ic-186-range-volume-interface`。合并提交 `aaeecc31192122fcd58cb7bfc45e96d3d140577b`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `e18ba07e69f1f9b110e242ca7f7eb8783d7f84e8` | `929e775cbf9db0343a000997f17424f95ff920d7` | 新文件 `Core/S1RangeVolumes.swift`（逐字节拷入）+ pbx 四行（Core 组，A1～A4）；单独可摘 |
| B | `46d9f35a6e8201ee4c9629321c94c8f3fde12434` | `0f6e25687f415342ab051f00fb69f36e368f9075` | `Services/S0LibraryScanService.swift` 三处插入（B1 记忆化存储、B2 记忆化类型、B3 读口方法）；依赖 A，只能 A→B 连续摘取 |
| C | `d2f21e5249646cee7d5d31114740effd076b7436` | `205a5e8b91ab94befca20cadbcec72b5a6be255a` | 新测试文件（逐字节拷入）+ pbx 测试登记四行（C1～C4）；依赖 A、B |

合并提交与 docs 提交见 `self-check.md` 第一节与第三节。

## 二、逐文件（白名单 4 路径，`git diff --name-only f550040..d2f21e5` 恰 4 行）

| 路径 | 子项 | 基线 blob | C 提交 blob | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Core/S1RangeVolumes.swift` | A（新建） | — | `095b98017d0f8f9ef6706dbad6d86ba5c4d300ce` | 逐字节拷自 `Tasks/decision-tools/ic186/S1RangeVolumes.swift`（+41）：`struct S1AssetByteCountTable: Equatable, Sendable`——`byteCountByAssetID`、`totalByteCount`（构造时求和）、`volume(of:) -> Int64?`（有一张不在表里为 nil、空范围 0）、`sharePercent(ofVolume:) -> Int`（四舍五入、钳 0～100、总占用 0 得 0）；只 `import Foundation` |
| `PhotoCleanupMVE/Services/S0LibraryScanService.swift` | B | `e40100309d9703f709527b001a690daaa4f564db` | `61675e9ed551fbf7713ba0ffa7f1200b607ba2f0` | +34／−0，三处纯插入：`private var memoizedByteCountTable`；`private struct MemoizedByteCountTable`；`func assetByteCountTable() -> S1AssetByteCountTable?`（锁内、`outcome == .completed` 才给表、键 = `libraryIdentifiers` 内全部资产含待删篮、未解析记 0、按修订号记忆化、不发任何源请求） |
| `PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift` | C（新建） | — | `890044fee1e17d865f694a11ab065bde0219053e` | 逐字节拷自 `Tasks/decision-tools/ic186/IC186RangeVolumeInterfaceTests.swift`，三条测试（+343） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、C | `3c2f0d5d8f30a8682bbdda3acd818ddd4bc04ccb` | `6f4bc1cb79af06526219a4b32e9a00056a4b1f28` | +8／−0。产品文件与测试文件各 PBXBuildFile 1、PBXFileReference 1、组 children 1、Sources 阶段 1，共 8 行照卡面原文（制表符与既有行相同） |

## 三、新 pbx id（登记前 fileRef 最大 `100000000000000000000086`、buildFile 最大 `200000000000000000000083`）

| 文件 | fileRef | buildFile | 所在组 |
|---|---|---|---|
| `S1RangeVolumes.swift` | `100000000000000000000087` | `200000000000000000000084` | Core（`300000000000000000000003`） |
| `IC186RangeVolumeInterfaceTests.swift` | `100000000000000000000088` | `200000000000000000000085` | 测试组（`300000000000000000000009`） |

## 四、测试函数新增（三条，既有测试文件一字未动）

`testIC186A_TableArithmetic`、`testIC186B_ServiceTableFollowsScanOutcome`、`testIC186C_SourceDiscipline`。XCTest 945 → 948。

## 五、占位值登记

本卡不改 `S2CalibrationConfiguration` 任何字段，`schemaVersion` 仍 7。不新增目录 key（目录 blob `911848e37193b1491b60274549db5ec1c0425a33` 不变、仍 281 条）。无新增登记制常量。

## 六、范围外未动

体积的界面呈现、「统计中」文案 key、S1 状态机与 App 接线、扫描完成时的刷新通知（V1 视图卡）；`已看`／`看过档`／`新增`（S1 重设计批第二张）；数据源协议 `Features/S0/S0CleanupDataProviding.swift`、桩 `Services/S0CleanupDataStub.swift`、App 入口、`Core/S1StateMachine.swift`、任何视图文件；目录；`Scripts/`、`.github/`；任何既有测试文件；SPEC 与 Decision_log。读口只加在扫描服务具体类型上，不进协议、不进桩、不进 App（卡裁定 一）。
