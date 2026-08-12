# IC-20260812-019 自验报告

## 一、当前结论

本卡实现、自验与 CI 均已完成。Windows 本地专项自验通过，共执行 54 项检查；macOS CI #16 成功，179 项 XCTest 全部通过，0 失败、0 unexpected；未签名 Release 构建及 IPA 上传成功。

## 二、实现范围

- 新增 `PhotoDeletionServicing`，声明 `startDeletion` 与 `systemFailureCallback` 两个现有外部可调用方法。
- `PhotoDeletionService` 遵循该协议；原有两个方法的签名、参数顺序、返回值与实现体保持不变。
- `CleanupCoordinator` 改为持有协议依赖，默认工厂仍创建 `PhotoDeletionService`。
- `S4StateMachine` 新增从 `S3StateMachine` 启动的冻结入口；只有该入口成功形成快照后，返回的 S4 实例才携带删除服务。既有 `start(snapshot:claimAndPersist:)` 保持原签名与状态机语义，但不能发起删除。
- 生产顺序保持为：冻结 S3 快照、持久化 S4 初态、协调器保存 S4、调用删除服务、进入执行页。
- `SpyDeletionService` 记录调用总数、分方法次数、调用顺序与收到的快照，不访问系统照片库。

## 三、专项测试

| 条款 | 测试 | 断言 |
|---|---|---|
| C34-020 | `testC34_020DeletionStartsOnlyAfterSnapshotFreeze` | 删除调用发生时，S3 已保存与 S4、Spy 收到值完全相同的冻结快照 |
| C34-047 | `testC34_047UnfrozenSnapshotCannotReachDeletionService` | 直接构造快照的旧 S4 入口不具备删除能力，Spy 调用总数为 0 |
| C34-104 | `testC34_104FreezeFailureDoesNotCallDeletionService` | 扫描未完成导致冻结失败时，不持久化 S4，Spy 删除调用为 0 |

测试静态总数由 176 增至 179；未新增 XCUITest。

## 四、自验命令

```powershell
& ./Scripts/verify-IC-20260812-019.ps1
```

专项脚本核对协议与依赖类型、生产调用顺序、真实服务方法体逐字不变、三条测试及 Spy 断言、179 项静态计数、范围外文件零改动、追溯文件摘要、无 XCUITest，并调用通用结构与硬编码门禁。Windows 本地执行退出码为 0，共通过 54 项专项检查；通用硬编码扫描结果为用户可见硬编码残留 0。

## 五、范围外文件与阻塞清单

- SPEC 文件：未改动。
- `Reports/TRACEABILITY-S3-S5.md`：未改动，SHA-256 仍为 `54B409B912A259CBE0028F35E70001CF2263A6A9E2799A1E75F34124055E7C50`。
- S3/S5 状态机、String Catalog、UI：未改动。
- 阻塞清单：无。

## 六、提交与 CI 证据

- 受验实现提交：`01ebf8263d20a58340aedd78be98cadd06d30eb0`。
- 最终 CI：`iOS 构建与自验 #16`，运行 ID `31620135992`，总耗时 10 分 28 秒，状态成功。运行链接：[引入删除服务冻结接缝 #16](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31620135992)；任务链接：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31620135992/job/94192607526)。
- XCTest：共执行 179 项，0 失败、0 unexpected；日志终态为 `TEST SUCCEEDED`，XCTest 步骤耗时 9 分 46 秒。
- 未签名 IPA：`PhotoCleanupMVE-unsigned.ipa`，242548 字节，文件 SHA-256 为 `c5db923c70e0b876585129ec9d3520ddfa3d850ba60f0a26649a8c0515e8b224`。
- 可下载产物：`PhotoCleanupMVE-unsigned-01ebf8263d20`，产物 ID `9151209182`，GitHub 归档摘要为 `26aed38bbbef7121a0281e0421b197193fb95a10297f4315762d795110ecf276`；[产物链接](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31620135992/artifacts/9151209182)。

## 七、末次提交说明

本报告回填提交自身为仓库末次提交，并使用 `[skip ci]`，因此不会产生晚于 #16 的报告专用 CI。Git 提交对象无法在自身内容中嵌入自身哈希；末次提交完整哈希以任务最终回传及仓库 `HEAD` 为准。最终受验产品与测试代码仍为上节记录的 `01ebf8263d20a58340aedd78be98cadd06d30eb0`，CI #16 对该提交完成了全部验收。
