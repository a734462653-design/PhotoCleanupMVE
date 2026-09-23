import Foundation

/// IC-153 A：扫描规则登记常量（批次 5.1 扫描服务）。
///
/// 分类、去重、聚合、缓存与回调节奏里的门槛**一律经本表取值**，不写裸数：
/// `IC153ScanServiceTests` 断言 3 钉住本表恰六个常量、每个都注明出处，
/// 分类与聚合文件内的数值字面量只允许 0 与 1。
///
/// 这些是扫描规则，不是标定参数：不进 `S2CalibrationConfiguration`、不上标定
/// 面板，`schemaVersion` 因而不变（任务卡「基线与分支」一节）。
enum S0ScanRules {
    /// 屏幕录制的文件名前缀，大小写敏感；只读视频主资源的原始文件名。
    /// 出处：SPEC-S0 v2 第十二节第 4 条（v2 订正，H68 实测见 Decision_log 第 175 条）。
    static let screenRecordingFilenamePrefix = "ScreenRecording_"

    /// 屏幕录制的像素尺寸，横竖不限。
    /// 出处：SPEC-S0 v2 第十二节第 4 条（H68 实测命中 34 个、误认 0，Decision_log 第 175 条）。
    static let screenRecordingPixelSize = S0ScanPixelSize(width: 1_206, height: 2_622)

    /// 缓存结构版本，从 1 起；文件内版本与此不符即整份作废、重扫。
    /// 出处：IC-153 裁定 四。
    static let cacheSchemaVersion = 1

    /// 每处理这么多项落盘一次；扫描结束另落一次。
    /// 出处：IC-153 裁定 四。
    static let persistEveryAssets = 200

    /// 字节取数的并发上限。
    /// 出处：IC-153 裁定 六。
    static let byteFetchConcurrency = 4

    /// 快照变化回调每秒至多几次。完成与失败那一次必达（不被节流丢掉）。
    /// 出处：IC-153 裁定 五。
    static let snapshotThrottleHz = 4
}
