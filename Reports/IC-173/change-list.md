# IC-173 变更清单

## 一、分支与提交

- 基线：`main` = `467fe74a0323c98e938142a2107f16843d21cc96`
- 分支：`probe/ic-173-material-dark-env`（探针分支，**不合并、不删**）
- 提交：
  - A `833e74cea6524ac5c5f860ae50d71656f54ec457`——`test(IC-173 probe): 系统材质加深色覆盖的像素探针（不合并）`
  - docs（本提交）——`docs(IC-173): 自验报告与变更清单（分支 #352 一次绿 898／0）`

## 二、文件变更（子项 A，恰 2 路径）

| 路径 | 类型 | 说明 |
|---|---|---|
| `PhotoCleanupMVETests/IC173MaterialDarkEnvironmentProbeTests.swift` | 新增 | 决策会话写、`cp` 逐字节拷入，`git hash-object` = `a7154bbe866d2d79d3d0533f2a72562cd7cc174a`，未改动任何一行；6 个 `func test`（A～F） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 修改 | 登记新测试文件，四行：`PBXBuildFile` 定义（id `200000000000000000000090`）、`PBXFileReference` 定义（id `100000000000000000000090`）、文件引用组成员、`PBXSourcesBuildPhase` 成员；均紧接 IC-171 已登记的 `IC171CategoryPageTrioTests.swift`（`074`／`071`）之后插入 |

本卡不改任何产品文件；不产生占位值登记（无 `S2CalibrationConfiguration` 字段变更，`schemaVersion` 仍 7）。

## 三、pbxproj 计数复核命令与结果

```
$ grep -c "100000000000000000000090" PhotoCleanupMVE.xcodeproj/project.pbxproj
3
$ grep -c "200000000000000000000090" PhotoCleanupMVE.xcodeproj/project.pbxproj
2
$ grep -oE "^\s*(1|2)00000000000000000000[0-9A-Fa-f]+ /\* [^*]* \*/ = \{isa = PBX(FileReference|BuildFile);" PhotoCleanupMVE.xcodeproj/project.pbxproj | awk '{print $1}' | sort | uniq -d
(空)
$ git diff --name-only 467fe74a..833e74c
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVETests/IC173MaterialDarkEnvironmentProbeTests.swift
```

登记前重扫（`main` 基线上）：`grep -n "100000000000000000000090\|200000000000000000000090" PhotoCleanupMVE.xcodeproj/project.pbxproj` 零命中，确认无撞号后才登记。

## 四、CI

- 运行 #352（run id `35995966216`），commit `833e74cea6524ac5c5f860ae50d71656f54ec457`：`completed` / `success`，898／0，真实退出码 0。
- 详细数据、全部 27 行 `IC173_PROBE`、分段耗时、IPA 校验见 `self-check.md` 第五、六节。
- CI 预算：1／3（预期只用 1，未再推）。

## 五、本地门禁（提交前，一次执行）

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check` | 0 |

## 六、范围外确认

- 未改动任何产品文件（`Features/`、`Core/`、`App/`、`Services/` 目录零改动）。
- 未触碰 `feature/ic-172-glass-always-dark` 分支（tip 核对见 `self-check.md` 第九节，未变）。
- 未修改 `<top>/SPEC-*.md`、`<top>/Decision_log.md`。
- 未执行合并、rebase、amend、force push。
- 本报告目录 `Reports/IC-173/` 随本 docs 提交推送到同一分支，未合并进 `main`。

## 七、40 位 SHA 核验命令与结果

```
$ git cat-file -e 467fe74a0323c98e938142a2107f16843d21cc96^{commit} ; echo $?
0
$ git cat-file -e 833e74cea6524ac5c5f860ae50d71656f54ec457^{commit} ; echo $?
0
$ git cat-file -e 3cf48335bdf1153f5f349e985fce3f5c2abefa29^{commit} ; echo $?
0
$ git cat-file -e e356aeda17da53a064892e04f39bea1032f5bf8d^{commit} ; echo $?
0
$ git cat-file -e 0134c84cb52aea523410ee2f9e05ddd0f54f5d14^{commit} ; echo $?
0
$ git cat-file -e b368a6caee846e664391b0620350395bfe6fbc7f^{commit} ; echo $?
0
$ git cat-file -e 6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d^{commit} ; echo $?
0
$ git cat-file -e a7cc1ec727a3a493f5263e688a316cbf4c743562^{commit} ; echo $?
0
$ git cat-file -e 5cb67332437a446d98733ddc942e2905392d2891^{commit} ; echo $?
0
$ git cat-file -e cc85fa4a7cfa272092a3acfade432d13de7e4e0b^{commit} ; echo $?
0
$ git cat-file -e dc7e49459f15fb6227c3f34903357ae490aaa7ed^{commit} ; echo $?
0
$ git cat-file -e 2734ccd0ef2f12fa4ce115f0136777321a96c548^{commit} ; echo $?
0
$ git cat-file -e fc6dd1436fa25b8298caca2f3d2266024859df4e^{commit} ; echo $?
0
$ git cat-file -e e7c1be085102b5d9685b0863f29feb6bfa006a38^{commit} ; echo $?
0
$ git cat-file -e 800791020a8923e44043fea49c9d766a7edcd307^{commit} ; echo $?
0
$ git cat-file -e 9db02b93eccbb87d126602901807e70823535111^{commit} ; echo $?
0
$ git cat-file -e 402cb6e52a11dc89ce2a8351b47314a5fe9185b8^{commit} ; echo $?
0
$ git cat-file -e 486bcb769b59eb1146c5a231c7998847206777cc^{commit} ; echo $?
0
$ git cat-file -e d373afc7125104c01acfc296829229090e6871ce^{commit} ; echo $?
0
$ git cat-file -e 1f8ff9248e312cd4a04faec559ea9f34540b1379^{commit} ; echo $?
0
$ git cat-file -e 180b052edf24f168712c6e58754c60b88b342175^{commit} ; echo $?
0
$ git cat-file -e 562f8b7afa14508e3efebbd57e980e275946ab95^{commit} ; echo $?
0
$ git cat-file -e a7154bbe866d2d79d3d0533f2a72562cd7cc174a^{blob} ; echo $?
0
```

全部 SHA 核验通过（退出码 0）。
