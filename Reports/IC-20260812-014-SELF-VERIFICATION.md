# IC-20260812-014 自验报告

## 一、当前结论

本卡实现、自验与 CI 均已完成。`Scripts/verify-IC-20260812-014.ps1` 退出码为 0，共通过 138 项检查；macOS CI 中 176 项 XCTest 全部通过，0 失败、0 unexpected，未签名 Release 构建成功。

## 二、范围与数量

| 项目 | 结果 |
|---|---:|
| B 组题卡条款复算 | 26 个唯一编号：C34 15 条、C5 11 条 |
| A 组迁移单元格 | 115：S3 28、S4 42、S5 45 |
| A 组不可达单元格 | 63 |
| A 组可达单元格 | 52 |
| 新增 XCTest 方法 | 27：A 组 1、B 组 26 |
| 原 XCTest 方法 | 149 |
| 当前 XCTest 方法总数 | 176 |
| B 组阻塞清单 | 无 |

## 三、实现证据

- `TransitionTableGuardTests` 在测试运行时从测试 bundle 读取 `Reports/TRACEABILITY-S3-S5.md`，从判定理由解析事件、起始状态和可达/不可达标记；测试源码不手工重录 115 个坐标。
- 守卫逐格遍历 115 个坐标；对 63 个不可达单元格，逐项断言状态机拒绝事件，或断言入口来源、入场事件等组合没有现有状态机 API 可构造。
- `CoverageGapTests` 为题卡列出的每个条款提供一个方法名含编号的独立测试，共 26 个且无重复、无遗漏。
- 未新增或修改任何产品源码；工程改动仅把两个 XCTest 源文件和追溯矩阵测试资源加入既有单元测试 target。
- 未新增 XCUITest 或 UI 测试 target。

## 四、自验命令

```powershell
& ./Scripts/verify-IC-20260812-014.ps1
```

执行结果：退出码 0，共 138 项检查全部通过。静态自验覆盖条款计数与映射、115 坐标解析、守卫数据来源、176 个测试方法计数、产品 Git blob 对比、XCUITest target/API 扫描和既有结构门禁。

## 五、XCTest 与 CI

- CI #11：失败于结构自验前置条件。浅克隆只包含当前提交，无法读取自验要求的产品基线 `5a76d734`；XCTest 尚未执行。已将同仓检出深度由 1 调整为 50，使基线对象可供 blob 核验。
- CI #12：结构自验通过，176 项 XCTest 中 175 项通过；A 组守卫把 S4 表入口名 `S3-2 外部源` 按字符串前缀误派给 S3 构造器，产生 1 个 unexpected。已改为先按完整入口名分派 S4，未修改产品代码或断言语义。
- CI #13：成功。运行链接：[修正 S4 外部源守卫分派 #13](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31587402502)；任务链接：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31587402502/job/94084319690)。结构自验通过；共执行 176 项 XCTest，0 失败、0 unexpected；未签名 Release 构建和产物上传均成功。
- CI #13 产物：`PhotoCleanupMVE-unsigned-0930b9d1d2cf`，IPA 大小 240239 字节，IPA SHA-256 为 `97a808731fb00fa7b006d2ec9061202834d4dc1ea8735d699d4fa025a957a4f8`。
