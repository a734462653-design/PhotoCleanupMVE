# IC-20260812-019 自验报告

## 一、当前结论

删除服务可注入接缝、三条专项 XCTest 与结构自验脚本已经落位。本地专项自验通过，共执行 54 项检查；macOS CI 编译、XCTest、未签名 IPA 证据将在提交后回填。

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
- 阻塞清单：本地结构自验阶段无；待 XCTest 与 CI 完成后最终确认。

## 六、提交与 CI 证据

- 受验提交：待提交。
- 最终 CI：待触发。
- XCTest：待 CI 回填。
- 未签名 IPA：待 CI 回填。
- 报告回填提交：待 CI 成功后以仅报告提交完成；届时将明确注明报告自身为末次提交。
