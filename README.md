# PhotoCleanupMVE

本工程实现 S3 → S4 → S5 最小可体验链路。应用目标与测试目标分别使用以下标识：

- 应用：com.iphonephotomanagement.PhotoCleanupMVE
- 测试：com.iphonephotomanagement.PhotoCleanupMVETests
- 最低系统：iOS 17.0
- Swift 语言版本：5.0

工程不包含 S1、S2，不声明网络、账号、收藏、隐藏或归相册能力。

## 目录

    PhotoCleanupMVE.xcodeproj/
    PhotoCleanupMVE/
      App/
      Core/
      Services/
      Features/
      Assets.xcassets/
      Info.plist
    PhotoCleanupMVETests/
    Scripts/
      selfcheck.ps1
      test-xcode.sh
    .github/workflows/ci.yml

## 本地自验

Windows 可执行结构与静态门禁：

    pwsh -File Scripts/selfcheck.ps1

安装 Xcode 的 macOS 可执行完整 XCTest：

    bash Scripts/test-xcode.sh

脚本会自动选择第一个可用的 iPhone 模拟器。没有可用模拟器时会明确失败，不会把未运行测试误报为通过。

## 占位资源

Assets.xcassets 中的 RECENTLY_DELETED_PLACEHOLDER.imageset 是 1 × 1 纯黑合法 PNG，仅用于保证资源目录与代码引用可构建。文件名故意保留 PLACEHOLDER，不能把它当作真实的系统“照片—最近删除”标注截图；取得真实截图后必须另行替换并复核说明文字。

## 持续集成

持续集成执行以下步骤：

1. 结构自验。
2. iOS 模拟器 XCTest。
3. 使用真机 SDK 构建未签名 PhotoCleanupMVE.app。
4. 将未签名应用放入 Payload 并压缩成 PhotoCleanupMVE-unsigned.ipa。
5. 校验 IPA 非空，并把字节数与 SHA-256 写入工作流日志和步骤摘要。

工作流不签名、不安装，也不访问任何 Apple 账号。

工作流不引用外部 GitHub Action。检出步骤只用运行器自带的 Git，从当前 GitHub 工程仓库按本次提交哈希取回源码；没有制品上传步骤，未签名 IPA 只在该次运行器内生成并以大小及摘要作为 CI 证据。
