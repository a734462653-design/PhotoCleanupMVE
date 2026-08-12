# IC-20260811-002 String Catalog 自验报告

生成日期：2026-08-11

## 1. 范围与基线

- 迁移基线：`2169523d362f08269b6fc5d0457180cc00bee9f0`。
- 扫描范围：产品目标 `PhotoCleanupMVE/App`、`Core`、`Services`、`Features` 下的 Swift 源码；覆盖 S3、S4、S5 页面及页面实际展示的 App、协调器与删除服务消息。
- 基线共有 80 个用户可见字符串出现位置，归并为 73 个唯一显示模板与 73 个 String Catalog key。
- 动态字符串表中把原 Swift 插值位置统一记为语义占位符，例如 `\(machine.assetCount)` 记为 `{count}`。比较时占位符两侧的每个字符、空格与全半角标点均参与 Ordinal 比较。
- 测试源码、测试断言、状态机、规格文件与十进制 MB/GB 格式化逻辑均未改动。

## 2. 迁移前后逐字比对

### 2.1 App、协调器与删除服务

| 原显示字符串或模板 | key | 新 zh-Hans 字符串或模板 | 结果 |
|---|---|---|---|
| 正在读取测试资产 | `app.loading.test_assets` | 正在读取测试资产 | 一致 |
| 本次清理会话已结束 | `app.session.finished` | 本次清理会话已结束 | 一致 |
| 照片库授权尚未完成 | `coordinator.authorization.not_completed` | 照片库授权尚未完成 | 一致 |
| 照片库权限不可用 | `coordinator.authorization.unavailable` | 照片库权限不可用 | 一致 |
| 无法识别照片库授权状态 | `coordinator.authorization.unknown` | 无法识别照片库授权状态 | 一致 |
| 无法清理会话记录：{error} | `coordinator.error.clear_session_record` | 无法清理会话记录：{error} | 一致 |
| 无法结束清理会话：{error} | `coordinator.error.end_session` | 无法结束清理会话：{error} | 一致 |
| 无法交接完成页：{error} | `coordinator.error.enter_completion` | 无法交接完成页：{error} | 一致 |
| 当前状态不能提交删除 | `coordinator.error.invalid_submission_state` | 当前状态不能提交删除 | 一致 |
| 无法保存完成页状态：{error} | `coordinator.error.persist_completion_state` | 无法保存完成页状态：{error} | 一致 |
| 无法保存执行状态：{error} | `coordinator.error.persist_execution_state` | 无法保存执行状态：{error} | 一致 |
| 无法持久化提交快照：{error} | `coordinator.error.persist_submission_snapshot` | 无法持久化提交快照：{error} | 一致 |
| 会话记录无法恢复，已重新载入测试资产 | `coordinator.error.restore_session` | 会话记录无法恢复，已重新载入测试资产 | 一致 |
| 无法返回确认页：{error} | `coordinator.error.return_to_confirmation` | 无法返回确认页：{error} | 一致 |
| 提交集合中存在无法取得的资产 | `deletion.failure.asset_unavailable` | 提交集合中存在无法取得的资产 | 一致 |
| 照片库权限不足 | `deletion.failure.insufficient_permission` | 照片库权限不足 | 一致 |
| 系统未返回失败说明 | `deletion.failure.missing_system_reason` | 系统未返回失败说明 | 一致 |

### 2.2 S3

| 原显示字符串或模板 | key | 新 zh-Hans 字符串或模板 | 结果 |
|---|---|---|---|
| 返回 | `s3.action.back` | 返回 | 一致 |
| 全部取消 | `s3.action.cancel_all` | 全部取消 | 一致 |
| 移除 | `s3.action.remove` | 移除 | 一致 |
| 提交删除 | `s3.action.submit_deletion` | 提交删除 | 一致 |
| 已收藏 | `s3.asset.favorite` | 已收藏 | 一致 |
| 待删除 {count} 张 | `s3.asset.pending_count` | 待删除 {count} 张 | 一致 |
| 请最终确认以下照片将被移入系统「最近删除」 | `s3.confirmation.recently_deleted_notice` | 请最终确认以下照片将被移入系统「最近删除」 | 一致 |
| 确认删除 | `s3.navigation.title` | 确认删除 | 一致 |
| 操作 | `s3.section.actions` | 操作 | 一致 |
| 待删除资产 | `s3.section.pending_assets` | 待删除资产 | 一致 |
| 状态 | `s3.section.status` | 状态 | 一致 |
| 没有待删除照片 | `s3.state.empty` | 没有待删除照片 | 一致 |
| 可以提交删除 | `s3.state.ready` | 可以提交删除 | 一致 |
| 正在计算照片体积 | `s3.state.scanning` | 正在计算照片体积 | 一致 |
| 没有可计算的照片体积 | `s3.volume.empty` | 没有可计算的照片体积 | 一致 |
| 照片体积 {known} | `s3.volume.exact` | 照片体积 {known} | 一致 |
| 照片体积 ≥ {known}；另有 {count} 项体积不可用 | `s3.volume.lower_bound` | 照片体积 ≥ {known}；另有 {count} 项体积不可用 | 一致 |
| 正在计算；当前已知 {known}，不可用 {count} 项（未完成） | `s3.volume.scanning` | 正在计算；当前已知 {known}，不可用 {count} 项（未完成） | 一致 |

### 2.3 S4

| 原显示字符串或模板 | key | 新 zh-Hans 字符串或模板 | 结果 |
|---|---|---|---|
| 执行删除 | `s4.navigation.title` | 执行删除 | 一致 |
| 全批成功 | `s4.section.all_succeeded` | 全批成功 | 一致 |
| 整批失败 | `s4.section.batch_failed` | 整批失败 | 一致 |
| 正在确认删除结果 | `s4.section.confirming_result` | 正在确认删除结果 | 一致 |
| 结果未知 | `s4.section.result_unknown` | 结果未知 | 一致 |
| 删除请求已提交 | `s4.section.submitted` | 删除请求已提交 | 一致 |
| 等待系统返回结果 | `s4.status.waiting_for_system_result` | 等待系统返回结果 | 一致 |
| 正在等待系统返回结果 | `s4.status.waiting_for_system_result_active` | 正在等待系统返回结果 | 一致 |
| 失败 {count} 张 | `s4.summary.failure_count` | 失败 {count} 张 | 一致 |
| 提交 {count} 张 | `s4.summary.submitted_count` | 提交 {count} 张 | 一致 |
| 成功 {count} 张 | `s4.summary.success_count` | 成功 {count} 张 | 一致 |
| 未处理 {count} 张 | `s4.summary.unprocessed_count` | 未处理 {count} 张 | 一致 |

### 2.4 S5

| 原显示字符串或模板 | key | 新 zh-Hans 字符串或模板 | 结果 |
|---|---|---|---|
| 我已清空最近删除 | `s5.action.confirm_recently_deleted_cleared` | 我已清空最近删除 | 一致 |
| 完成 | `s5.action.finish` | 完成 | 一致 |
| 离开 | `s5.action.leave` | 离开 | 一致 |
| 返回确认页 | `s5.action.return_to_confirmation` | 返回确认页 | 一致 |
| 已保留原提交集合，可返回确认页再次尝试 | `s5.failure.retry_notice` | 已保留原提交集合，可返回确认页再次尝试 | 一致 |
| 清理结果 | `s5.navigation.title` | 清理结果 | 一致 |
| 系统标注截图占位图，不属于正式交付素材 | `s5.placeholder.disclaimer` | 系统标注截图占位图，不属于正式交付素材 | 一致 |
| 照片已移入系统「最近删除」，仍由系统保留。App 无法读取或清空该位置。请打开系统「照片」，进入「实用工具」中的「最近删除」，由你完成清空，然后返回本页。 | `s5.recently_deleted.boundary_notice` | 照片已移入系统「最近删除」，仍由系统保留。App 无法读取或清空该位置。请打开系统「照片」，进入「实用工具」中的「最近删除」，由你完成清空，然后返回本页。 | 一致 |
| 本次删除未完成 | `s5.section.deletion_incomplete` | 本次删除未完成 | 一致 |
| 本次删除结果未知 | `s5.section.deletion_result_unknown` | 本次删除结果未知 | 一致 |
| 已移入最近删除 | `s5.section.moved_to_recently_deleted` | 已移入最近删除 | 一致 |
| 设备可用空间仍在等待你的系统操作 | `s5.status.device_space_waiting` | 设备可用空间仍在等待你的系统操作 | 一致 |
| 处理结果未知 | `s5.status.result_unknown` | 处理结果未知 | 一致 |
| 处理结果：成功 {success} 张，失败 {failure} 张，未处理 {unprocessed} 张 | `s5.summary.failure_result` | 处理结果：成功 {success} 张，失败 {failure} 张，未处理 {unprocessed} 张 | 一致 |
| 处理结果：成功 {success} 张，失败 0 张，未处理 0 张 | `s5.summary.success_result` | 处理结果：成功 {success} 张，失败 0 张，未处理 0 张 | 一致 |
| 请人工核对照片原位置与系统「最近删除」 | `s5.unknown.manual_verification_notice` | 请人工核对照片原位置与系统「最近删除」 | 一致 |
| 本次清理的照片共 {value} | `s5.volume.exact` | 本次清理的照片共 {value} | 一致 |
| 本次清理的照片共至少 {value}；另有 {count} 项体积不可用 | `s5.volume.lower_bound` | 本次清理的照片共至少 {value}；另有 {count} 项体积不可用 | 一致 |
| 该数值只描述原提交集合的体积，不代表处理结果或设备可用空间变化 | `s5.volume.original_submission_disclaimer` | 该数值只描述原提交集合的体积，不代表处理结果或设备可用空间变化 | 一致 |

### 2.5 S4/S5 共享模板

| 原显示字符串或模板 | key | 新 zh-Hans 字符串或模板 | 结果 |
|---|---|---|---|
| 本次提交 {count} 张 | `submission.asset_count` | 本次提交 {count} 张 | 一致 |
| 等待系统回调超时 | `submission.unknown_reason.callback_timeout` | 等待系统回调超时 | 一致 |
| 应用在取得终态前被系统终止 | `submission.unknown_reason.process_terminated` | 应用在取得终态前被系统终止 | 一致 |

逐字机器复核结果：73/73 个归一化显示模板 Ordinal 相等；基线独有模板 0，Catalog 独有模板 0。20 个动态模板使用互异哨兵值执行替换，20/20 渲染结果与原 Swift 插值结果 Ordinal 相等。

## 3. String Catalog 与图片结构

| 检查项 | 结果 |
|---|---|
| `sourceLanguage` | `zh-Hans` |
| Catalog key 数 | 73 |
| 产品源码唯一引用 key 数 | 73 |
| 缺失 key | 0 |
| 未引用 key | 0 |
| `.xcstrings` 语言集合 | 仅 `zh-Hans` |
| 非 `zh-Hans` 语言条目 | 0 |
| 图片语言集合 | 仅 `zh-Hans` |
| 当前绑定图片 | 仅原 `RECENTLY_DELETED_PLACEHOLDER.png` 一份 |
| 原 PNG 是否替换 | 否；Git 对象哈希仍为 `26a8c68efad2a094e8fe6d850426b651d353c568` |

`RECENTLY_DELETED_PLACEHOLDER.imageset` 的 1x、2x、3x universal 槽均声明 `locale: zh-Hans`，只有 1x 继续绑定原占位 PNG；没有新增图片文件或其他语言条目。

## 4. 硬编码扫描结果

执行命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Scripts\scan-hardcoded-user-visible-strings.ps1
```

结果：退出码 0。

| 项目 | 数量 |
|---|---:|
| 用户可见硬编码残留 | 0 |
| 非用户界面断言诊断 | 11 |
| 规格锁定格式豁免 | 2 |
| `Info.plist` 范围边界 | 2 |

11 条汉字字符串均为 `precondition` 或 `preconditionFailure` 开发诊断，不进入用户界面。两条规格豁免是 `DecimalVolumeFormatter` 的 `GB` 与 `MB` 输出；本卡明确禁止本地化改造，保持原逻辑与原字节不变。

`Info.plist` 中以下两项属于 Bundle/系统权限元数据，不由本卡指定的 `Localizable.xcstrings` 驱动，也不属于 S3/S4/S5 页面 Swift 扫描范围，因此未擅自新增第二个 `InfoPlist.xcstrings`：

| 文件 | key | 当前值 | 范围说明 |
|---|---|---|---|
| `PhotoCleanupMVE/Info.plist` | `CFBundleDisplayName` | 照片清理 MVE | Bundle 元数据 |
| `PhotoCleanupMVE/Info.plist` | `NSPhotoLibraryUsageDescription` | 用于读取测试资产、计算体积并提交你确认的照片删除操作。 | 系统权限元数据 |

## 5. CI 与测试

| 检查项 | 当前结果 |
|---|---|
| Windows 结构自验 | 通过；`Scripts/selfcheck.ps1` 退出码 0 |
| 硬编码扫描 | 通过；用户可见残留 0 |
| 测试源码与断言 | 相对基线逐文件 Git blob 一致 |
| XCTest 静态方法数 | 136；分布为 15、32、38、25、20、6 |
| 验证提交 | `9ac4764606fdbb8c1d0ca52928af611aa93100e8` |
| macOS 环境 | Xcode 16.4；iPhone 16 模拟器；iOS 18.5 |
| XCTest 实跑 | 通过；136 项，0 失败，0 unexpected；日志出现 `TEST SUCCEEDED` |
| Release 真机 SDK 构建 | 通过；日志出现 `BUILD SUCCEEDED` |
| CI 运行 | [iOS 构建与自验 #6](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31457808371)，状态成功，耗时 3 分 29 秒 |
| CI 任务 | [构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31457808371/job/93675131847) |

CI #6 同时成功执行结构自验、String Catalog 编译、资产目录编译、模拟器 XCTest、Release 无签名构建与未签名 IPA 上传。上述 136 项测试与构建结论均来自新提交的 macOS CI 日志，不以 Windows 静态计数代替。
