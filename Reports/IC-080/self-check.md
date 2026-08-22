# IC-080 自验报告（merge-ic074-079-to-main）

## 结论（先行）

`main` 已自 `8acf43d05d6fa0d7a74024baf78b29d775e1d820` 以 `git merge --ff-only` 快进至 `7a11a182460ca34eb542414c2aefa1c2bf6f3205`（`origin/feature/ic-079-fast-paging-window` 尖，开工时 `git rev-parse` 实测；父 `42be5411992eb456d228a7bc5f0823fbd5e74c6d`），一次成功（1/3）。`main` CI #131 success：XCTest **455 项、0 失败**，9 步 success，`test_status=0`。快进带入 31 个提交（卡内"预期 29"为估计值，实测 31，逐个列于变更清单），无 merge 提交，`probe/ic-067-screenshot-subtype` 独有提交 0 个进入，六个 feature 分支远端指针未变。本卡自身只有一个 docs 提交（`Reports/IC-080/` 两文件）。G144～G147 全部满足。

## 输入与核验（R1，均①）

- 开工 `git status --porcelain` 为空；当前分支 `feature/ic-079-fast-paging-window`（尖 `7a11a18`），`main` = `origin/main` = `8acf43d`。
- `git fetch origin --prune`：首次 TLS 握手失败（`schannel: failed to receive handshake`），重试成功（退出码 0）。
- `git merge-base origin/main origin/feature/ic-079-fast-paging-window` = `8acf43d05d6fa0d7a74024baf78b29d775e1d820` ✓
- 祖先链 `git merge-base --is-ancestor`（六次均为真）：`origin/main` → `ic-074`（`11b07f3972b5e358247f8b2b12d1fc5e45b8289f`）→ `ic-075`（`c99b0da1738c91757816d1ffc376d5fd44d340a3`）→ `ic-076`（`10ff08b1eb63f1ed9110ce4d0f4a32b204ffa300`）→ `ic-077`（`253212e5c7fb1ce110876e3e746ad76d63fe77f7`）→ `ic-078`（`5691767763348db275b63d7b32bdd9351bc157ee`）→ `ic-079`（`7a11a182460ca34eb542414c2aefa1c2bf6f3205`）✓
- `git log --merges 8acf43d..origin/feature/ic-079-fast-paging-window` 为空 ✓
- `git rev-list --count 8acf43d..origin/feature/ic-079-fast-paging-window` = 31。
- `git checkout main && git merge --ff-only origin/feature/ic-079-fast-paging-window`：`Updating 8acf43d..7a11a18 Fast-forward`，28 个文件 +5013/−664，退出码 0。
- `git push origin main`：前两次 TLS 握手失败，第三次成功 `8acf43d..7a11a18 main -> main`；`origin/main` = `7a11a18…`。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G144 | 满足① | `git rev-parse main` = `7a11a182460ca34eb542414c2aefa1c2bf6f3205`；`git log --merges 8acf43d..main` 为空；`git diff 42be541 main -- . ':(exclude)Reports/' \| wc -l` = 0 |
| G145 | 满足① | `main` CI #131（id `32581225913`）success，9 步全部 success；被测 SHA `7a11a182460ca34eb542414c2aefa1c2bf6f3205`；`Executed 455 tests, with 0 failures (0 unexpected) in 19.964 (46.638) seconds`；`test_status=0`；IPA `PhotoCleanupMVE-unsigned.ipa` 753701 字节，SHA-256 `4bbc359f9b0524cfbdfa635cac61429f43f1e1bba1d339a35a9ad917300c6086`（CI 报告值；与 #130 的 `ad5904d3…` 不同，卡已说明不要求相同），artifact `PhotoCleanupMVE-unsigned-7a11a182460c` 经 `gh run download`（前两次 EOF，第三次成功）本地 `sha256sum` 一致 |
| G146 | 满足① | 快进前后六个 `origin/feature/ic-07x-*` 指针逐一 `diff` 相同（`11b07f3`、`c99b0da`、`10ff08b`、`253212e`、`5691767`、`7a11a18`）；`git log origin/main..origin/probe/ic-067-screenshot-subtype` 的提交与 `8acf43d..main` 交集为 0 |
| G147 | 满足① | docs 提交只含 `Reports/IC-080/self-check.md`、`Reports/IC-080/change-list.md`（`git show --stat` 见下）；`main`（`7a11a18`）上 `selfcheck.ps1` 退出码 0、`scan-hardcoded-user-visible-strings.ps1` 0、`git diff --check` 0 |

## 报告提交方式

本报告与变更清单以一个 docs 提交推送到 `main`（第二次授权推送）；该推送只改 `Reports/**`，按 `paths-ignore` 不触发 CI（预期）。报告无法引用自身提交的 SHA（禁止 amend），以 `git log -1 main` 为准。

## 发现但未处理

1. 本机到 GitHub 的 TLS 握手间歇失败（fetch/push/artifact 下载各需 2～3 次重试），与代码无关。
2. 卡内"预期 29 个提交"与实测 31 不符（IC-077 含 2 个测试提交、IC-078 含 1 个编译修正提交等），已按实测列出。
