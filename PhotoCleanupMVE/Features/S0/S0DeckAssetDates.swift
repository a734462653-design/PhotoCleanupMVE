import Photos

/// IC-163 C（裁定 四）：类别页时间排序用的拍摄日期。
///
/// `S0CategoryAsset` 不加字段（它的构造点里有两处在 `main` 的既有测试里），扫描缓存里的
/// `creationDate` 也不出数据源协议，故由本文件按标识一次取全。**同步调用会阻塞调用线程**：
/// 页面在 `.task` 里经 `Task.detached` 调它，不在主线程上取。
///
/// `creationDate` 为 nil 的资产不入字典——排序与分节把它们归到最后一节「未知日期」。
enum S0DeckAssetDates {
    static func creationDates(forLocalIdentifiers ids: [String]) -> [String: Date] {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var result: [String: Date] = [:]
        fetch.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate {
                result[asset.localIdentifier] = date
            }
        }
        return result
    }
}
