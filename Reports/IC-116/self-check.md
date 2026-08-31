# IC-116 自验报告：CI 工具链切换 Xcode 26——**绿**

## 结论（先行）

**IC-116 绿，一次 CI 通过。** 分支 tip = `d81c6a65ac46e133c097c80a98e1283c7ce137d5`（唯一授权改动），
CI **#224**（run 33308193560）success，**XCTest 575 项 0 失败**（与 IC-115 #223 计数一致），真实退出码 0，
IPA 1018330 字节，SHA-256 `3a0e40b9a4baf841078ed845dc54544357f594592a44604518bc5d6e56704098`。
零产品改动；`Scripts/`、产品、测试零 diff。CI 预算用 **1/2**。IC-117 开工条件满足。

## 输入与范围

- 输入：`DISPATCH-20260830-115-117.md` IC-116 节（照原单逐字执行）+ v2 联动单接链条款。
- 继承提交：`2f5a680`（IC-115 v2 报告 docs 提交；开工时工作树净）。
- 目标分支：`feature/ic-110-visual-batch`。
- 范围边界：`ci.yml` 一处新增步骤，其余全部零改动。

## 唯一授权改动（commit `d81c6a6`，`ci.yml` +17 行一处）

新增步骤「选择 Xcode 26 工具链（IC-116）」，插在检出与「显示 Xcode 环境」之间：

1. `ls /Applications | grep -E '^Xcode'` 打印全部 Xcode 安装（**实证进日志**）；
2. 按 `^Xcode_26(\.[0-9]+)*\.app$`（严格数字点号命名，天然排除 beta/RC 后缀）过滤后
   `sort -V | tail -1` 取实际存在的最高 26.x 稳定版——**版本号来自 runner 实时 `ls`，非臆造**；
3. 选中路径写入 `$GITHUB_ENV` 的 `DEVELOPER_DIR`（"或等效一处"），作用于后续全部步骤；
4. 不存在任何 26.x 稳定版时显式失败退出。

除此步骤外 `ci.yml` 零 diff（`git show d81c6a6 --stat`：1 file, +17）。

## 验收门禁逐条

| 门禁 | 结果 | 依据（均 ①，出自 #224 日志） |
|---|---|---|
| `ls` 实证后选最高 26.x 稳定版 | ✅ | 日志列出 Xcode_26.0 / 26.0.1 / 26.1 / 26.1.1 / 26.2 / 26.2.0 / 26.3 / 26.3.0（及 16.x 系列）；脚本选中 `/Applications/Xcode_26.3.0.app` |
| `DEVELOPER_DIR` 生效 | ✅ | 后续步骤 env 显示 `DEVELOPER_DIR=/Applications/Xcode_26.3.0.app/Contents/Developer`；`xcodebuild -version` 输出 **Xcode 26.3（Build 17C529）** |
| 预期 success、与 IC-115 相同计数 0 失败 | ✅ | Executed **575** tests, 0 failures（#223 亦为 575/0）；job success，工作流 `exit "$test_status"` ⇒ 真实退出码 0 |
| IPA 登记 | ✅ | 1018330 字节，SHA-256 `3a0e40b9a4baf841078ed845dc54544357f594592a44604518bc5d6e56704098`（Xcode 16.4 下 #223 为 991043 字节，工具链变更引起产物差异属预期） |
| `Scripts/`、产品、测试零改动 | ✅ | 本卡仅 `ci.yml` 一文件入提交 |

## 版本号登记（①实证，#224 日志）

| 项 | 值 |
|---|---|
| Xcode | 26.3（Build 17C529），`/Applications/Xcode_26.3.0.app` |
| SDK（XCTest） | iPhoneSimulator26.2.sdk（23C57） |
| SDK（IPA 构建） | iPhoneOS26.2.sdk |
| XCTest 模拟器 | iPhone 16（id `E514A76C-D366-4B28-A6F6-E62A57B237C3`），**iOS 18.5** |
| runner 镜像 | macos-15-arm64，Version 20260727.0256.1 |
| 镜像另有 iOS 26 运行时 | simctl 列出 iOS 26.0 / 26.1 / 26.2（可用未使用，见下） |

## 本地门禁（①）

提交前均退出码 0：`git diff --check`、`Scripts/selfcheck.ps1`、`Scripts/scan-hardcoded-user-visible-strings.ps1`。

## 发现但未处理的问题（按纪律只报告不修）

1. **XCTest 仍跑在 iOS 18.5 模拟器上，未跑到 iOS 26 运行时。** `Scripts/test-xcode.sh` 的既有逻辑取
   `-showdestinations` 的**第一个** iPhone 模拟器，Xcode 26.3 下清单以 iOS 18.5 设备开头，故目的地未变。
   工具链/SDK 已切到 26.x，但"iOS 26 模拟器上的行为差异"在本轮**未被暴露**——若决策会话期望测试跑在
   iOS 26 运行时，需另行授权改 `test-xcode.sh` 的目的地选择（本卡 `Scripts/` 零改动，未动）。
   IC-117 的 `glassEffect` 分支在 iOS 18.5 模拟器下会走 `#available` 回落路径，玻璃渲染差异同样不会在
   CI 像素探针中显影，属同一根因。
2. `ls` 实证显示镜像同时存在 `Xcode_26.3.app` 与 `Xcode_26.3.0.app` 等成对命名（16.x 亦然），
   `sort -V` 取 `26.3.0`；两者指向同一 Build 17C529，无歧义风险，仅登记。

## 人工判定项

无本卡新增（零产品改动）。

## 报告提交

`Reports/IC-116/` 随 docs 提交推送（同卡同分支追加，需引用推送后才产生的 #224 编号与 IPA 哈希）；
命中 `paths-ignore` 不触发 CI，属预期。验证产品代码的运行为 **#224**（被测提交 `d81c6a6`）。
