# IC-093 自验报告（image-upgrade-and-mark-style）

## 结论（先行）

R1（图像替换只升不降）与 R2（待删标记双色化）完成，各自独立提交，另有一个测试修正提交。分支 `feature/ic-093-image-upgrade-mark-style` 自 `feature/ic-090-strip-corner-pinch-end` = `420e72a` 切出，最终被测 `c2be235dad092e3819dc8fbcccadf076f5eab893`。

**CI 结果：CI #162 success。** 被测 `c2be235dad092e3819dc8fbcccadf076f5eab893`，XCTest **492 项、0 失败**（= 482 + 10 − 0），9 步全 success，真实退出码 `test_status=0`；IPA 786812 字节、SHA-256 `f561d1ad…9850`，本地重下复核一致。CI 用了 **2 次**（上限 3 次，剩 1 次）。

闸门 A、B、C、D 均未触发。既有断言**一条未削弱、一个未删**。

两项都是"改完就能看出来"的改动，但**能不能真正消掉闪替、深色下标记好不好认，只有真机说了算**：H39、H40 见下。

## R1：抑制判定的单一入口

**`S2TemporaryPhotoImageView.requestImage(for:trigger:)` 的结果处理闭包内**（`PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift`），位置在既有 `guard S2ImageRequestDecision.shouldDisplay(…)` 之后、`image = nextImage` 之前：

```
let candidatePixelSize = S2ImageUpgradeDecision.pixelSize(of: nextImage)
let displayedImage = displayedAssetID == requestedAssetID ? image : nil
if let displayedImage {
    guard S2ImageUpgradeDecision.shouldReplaceDisplayedImage(…) else {
        onImageReplacementSuppressed(…)
        return
    }
}
```

选这里的理由：**这是产品里唯一一处把 `image` 换掉的位置**。判定挂在这里，就只影响"返回结果是否上屏"，请求尺寸算法、发起时机、节流、`S2ImageRequestStrategy` 结构一行都不用动（闸门 A 未触发）。

三条边界都由这段代码的形状本身保证，而不是靠额外条件：

- **资产切换不受限**：`displayedAssetID != requestedAssetID` 时 `displayedImage` 为 `nil`，整个 `if` 不进，决策 28 的首次加载行为一字不动。
- **失败 / 取消不受影响**：它们在更早的 `guard let nextImage = result.image else` 分支里就返回了，根本到不了这里。
- **`finalImageOnly` 不受影响**：降质结果被既有 `shouldDisplay` 挡在前面。

判据是**像素面积**（宽 × 高）而不是逐边比较——卡内写的是"像素尺寸（宽×高）"。副作用是：宽变小但总面积更大的结果会被放行（C0 里有这条断言）。若技术负责人要的是"逐边都不小于"，请明示，这是一行的改动。

像素尺寸取 `点尺寸 × scale`。PhotoKit 返回的图 `scale` 恒为 1，因此与既有 `图片替换` 事件里 `pixel=` 的口径完全一致；夹具用 `scale ≠ 1` 的图时以本式为准（C0 有断言）。

## R2：两处标记的渲染改动点

新增 `S2PendingDeletionMark`（`S2View.swift`），两处调用点收敛到它：

| 改动点 | 改前 | 改后 |
|---|---|---|
| `S2BottomStripView.stripMark(for:)` | `Image(systemName:).resizable().scaledToFit().frame(…)`，前景色由环境决定 | `S2PendingDeletionMark(size: mark.size)` |
| `S2View.primaryMarkOverlay(safeAreaInsets:)` | 同上 | `S2PendingDeletionMark(size: size)` |

渲染本身：`symbolRenderingMode(.palette)` + `foregroundStyle(Color.white, Color.black.opacity(0.55))`。`Color.white` / `Color.black` 是固定 sRGB 常量而不是语义色，所以两个 `colorScheme` 下渲染逐像素相同——D1 / D2 直接比对位图。

**两处调用点的其余修饰符一行未动**：横栏的 `.accessibilityHidden(true)`；主图的 `keyframeAnimator`（脉冲）、`accessibilityLabel`、两处 `padding`、`frame(alignment: .topTrailing)`、`allowsHitTesting(false)`。尺寸仍来自 `mark.size` 与 `S2PrimaryMarkPresenter.markSize(bottomStripMarkSize:)`，显示条件仍是 `mark.isShown` 与 `showsMark(interfaceVisibility:isMarked:)`，圆角裁切关系不变。

`S2BottomStripMarkPresentation.symbolName` 与 `S2PrimaryMarkPresenter.symbolName` 两个常量保留未改（既有断言直接比对它们），D2 另加一条断言确认它们与 `S2PendingDeletionMark.symbolName` 相等。

## CI #161 暴露的两条（都是我自己写错的断言）

CI 用了 2 次（上限 3 次，剩 1 次）。**#161：492 项 2 失败**，两条都在本卡新增的测试上，产品代码一行没动；其余 8 个新增测试与 IC-063～IC-090 既有门禁全过。

**(1) C0 的「更大」用例数据算错（①）**：我写的是「3060×4080 已显示，4032×3024 更大 → 放行」，但 `4032 × 3024 = 12 192 768` **小于** `3060 × 4080 = 12 484 800`。产品按面积判定把它拦下，是对的；错的是我的用例。这两个都是真实的 iPhone 照片尺寸，**单边更宽不等于像素更多**——正好是"面积 vs 逐边"这个选择在实际数据上会分岔的例子。处置：「更大」改用 4080×5440，并把 4032×3024 这一例**保留为反例断言**，把这个反直觉的事实钉进门禁。

**(2) C6 用错了加载态判据（①）**：断言 `states.last == .loading`，实测得到 `nil`。`setLoadState` 只在加载态**变化**时才回调，而初始态就是 `.loading`，所以 `finalImageOnly` 下首次降质不上屏时压根没有回调。判据改为「从未回调过 `displayed` / `failed`」，与「没离开过 `loading`」等价且成立。

两条都只改测试。**产品的 R1 判定在 #161 里就已经被 C1～C5 全部验证通过**。

## 输入、继承与范围

- 任务卡 `IC-20260824-093-image-upgrade-and-mark-style`；上游证据 `Reports/IC-090/phase3-pinch-end-analysis.md`（①因果链）、Lynn 2026-08-24 定案（图像替换选 C、标记样式选 A）、Lynn 2026-08-23 H36 附带反馈。
- 开工前 `git status --porcelain` 为空；按下发语从 `420e72a` 切新分支。IC-092 执行会话已停（同一会话，先完成 IC-092 阶段一交付后才开工）。
- 范围边界：只改 `S2TemporaryPhotoImageStrategy.swift`、`S2View.swift`、`PhotoCleanupMVEApp.swift`、`S2NativePhotoPager.swift`、两个测试文件、`Reports/IC-068/export-format.md`。`S2Calibration.swift`、`S2StateMachine.swift`、`Localizable.xcstrings`、`Scripts/`、`ci.yml`、SPEC、Decision_log 一个未动。未新增 XCUITest，未合并主干，未 force push，未改写历史。

## 提交清单

| 提交 | 归属 | 内容 |
|---|---|---|
| `b3e4f7e` | R1 | 只升不降判定 + `图片替换被抑制` 事件 + 上下文透传 + C0～C6 与事件断言 + `export-format.md` 追加一节 |
| `0bc8401` | R2 | `S2PendingDeletionMark` + 两处调用点 + D1～D3 断言 + `renderStrip` 加 `colorScheme` 形参 |
| `c2be235` | 测试修正 | C0 与 C6 两条断言的处置（见下节），产品代码零改动 |

两个提交互不依赖，各自可单独 cherry-pick（③源码推断；本机无 Xcode，只有 tip 经 CI 实测）。产出方式：先在工作树里做完两项并跑通本地门禁，再取最终态快照 → `git checkout -- .` 回到 `420e72a` → 只重建 R1 并提交 → 把快照原样放回并提交 R2。七个文件 `cmp` 与快照**逐字节相同**。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G197** C1～C6 + `图片替换被抑制` 事件断言 + `export-format.md` 只增不删 | 满足① | 见下表。`git diff 420e72a..HEAD -- Reports/IC-068/export-format.md` = **13 增 0 删** |
| **G198** D1～D3 | 满足① | 见下表 |
| **G199** IC-063～IC-090 既有门禁 + 本地三项 | 满足① | CI 内既有测试全过（含 IC-090 G180 / G181 两条像素门禁）。本地：`Scripts/selfcheck.ps1` 退出码 **0**；`Scripts/scan-hardcoded-user-visible-strings.ps1` 退出码 **0**（目录 171 / 引用 171、残留 0）；`git diff --check` 退出码 **0** |
| **G200** CI success / 计数算式 / IPA 校验 | 满足① | 计数算式：**482 + 10 − 0 = 492** |

### C1～C6（R1，夹具驱动，真机未覆盖）

| 断言 | 结果 | 测试函数与要点 |
|---|---|---|
| **C0** 判定纯函数 | 满足① | `testIC093C0UpgradeDecisionComparesPixelArea`：无已显示图 → 放行；3060×4080 vs 90×120 → 拦；等尺寸 → 放行（边界不严格）；4080×5440 更大 → 放行；**4032×3024 反例 → 拦**（单边更宽但面积更小，CI #161 实测钉住）；100×100 vs 50×300（宽变小、面积更大）→ 放行；`pixelSize(of:)` 对 `scale == 1` 与 `scale == 2` 的同一 `CGImage` 给出相同像素尺寸 |
| **C1** 同资产降质结果被抑制 | 满足① | `testIC093C1LowerResolutionResultIsSuppressedForSameAsset`：宿主真实视图 → 交付 `finalImage 3060×4080`（替换回调 1 次、加载态 `displayed`）→ `requestRevision += 1` 触发**真实的**捏合松手重请求（`scaleChangePolicy == .pinchEnded`，请求数变 2）→ 交付 `degradedPreview 90×120`：替换回调仍是 1 次、抑制读数 1 条且 `displayed=(3060,4080)` / `candidate=(90,120)` / `result=degradedPreview`、加载态仍 `displayed`、从未进 `failed`；随后到达的更大最终图照常上屏（替换回调变 2 次、抑制读数仍 1 条） |
| **C2** 首次降质照常显示 | 满足① | `testIC093C2FirstDegradedPreviewStillDisplays`：无已显示图时交付 `degradedPreview 90×120` → 替换回调 1 次、抑制读数 0、加载态 `displayed`。决策 28 不回归 |
| **C3** 资产切换不受限 | 满足① | `testIC093C3AssetChangeAllowsLowerResolutionPreview`：`asset-2` 已显示 3060×4080 → 把宿主的 `assetID` 改成 `asset-3`（真实 `.assetChange` 路径，`asset-3` 请求数 1）→ 交付 `degradedPreview 90×120`：替换回调变 2 次、抑制读数 0 |
| **C4** 等尺寸 / 更大照常替换 | 满足① | `testIC093C4EqualOrHigherResolutionReplaces`：1000×1000 → 1000×1000（替换）→ 2000×1000（替换），抑制读数全程 0 |
| **C5** 已有图像时失败不进失败态 | 满足① | `testIC093C5FailureWithDisplayedImageKeepsDisplayedState`：已显示后新请求交付 `.failure` → 加载态仍 `displayed`、从未进 `failed`、替换回调不增、抑制读数 0（失败没有图像，压根到不了只升不降判定）。IC-076/077 链与第 123 条取定不变 |
| **C6** `finalImageOnly` 不受影响 | 满足① | `testIC093C6FinalImageOnlyPolicyIsUnaffected`：该策略下首次降质就不上屏（从未回调过 `displayed` / `failed`、抑制读数 0）；最终图照常上屏；已显示后再来降质仍由既有 `shouldDisplay` 挡下、抑制读数仍 0。与 `main` 行为一致 |
| 事件 details | 满足① | `testIC093SuppressedReplacementEventDetails`：`event=图片替换被抑制\tsource=S2TemporaryPhotoImageView.requestImage\tdetails=asset=asset-2；result=degradedPreview；displayed=(w=3060.000000,h=4080.000000)；candidate=(w=90.000000,h=120.000000)`；停止录制后该入口零副作用 |

### D1～D3（R2，夹具驱动，真机未覆盖）

| 断言 | 结果 | 测试函数与要点 |
|---|---|---|
| **D1** 横栏标记双色 + 两模式一致 | 满足① | `testIC093D1StripMarkIsFixedTwoToneAcrossColorSchemes`：走**真实的** `S2BottomStripView` 以 `ImageRenderer` scale=3 渲染，内容取中灰 `Color(white: 0.5)`。取证只看"标记前后有差异"的像素（同一项目在 marked / unmarked 两次渲染里比对），框角的背景像素两次相同因而不会被误判为符号或圆底：(a) 差异像素里存在亮度 > 200 的 —— 白符号；(b) 存在 `20 < 亮度 < 内容亮度 − 20` 的 —— 半透明黑圆底（不是纯黑、也不是内容色）；(c) 浅色与深色两个 `colorScheme` 下标记框位图**逐像素相同** |
| **D2** 主图标记同 D1 | 满足① | `testIC093D2PrimaryMarkIsFixedTwoToneAcrossColorSchemes`：先断言两处调用点用的是同一个符号常量（`S2PrimaryMarkPresenter.symbolName == S2BottomStripMarkPresentation.symbolName == S2PendingDeletionMark.symbolName`）与 `circleOpacity == 0.55`；再按主图实际尺寸（`markSize(bottomStripMarkSize: 出厂 14)` = 28）渲染两处**共用的** `S2PendingDeletionMark`，判据同 D1 的 (a)(b)(c) |
| **D3** 圆角裁切与既有断言保持 | 满足① | D1 末尾：已标记项目右上角沿 45° 对角线偏移 0/1 仍为背景（与 IC-090 G181(a) 同判据，换新颜色后仍成立）。**G181 本身一字未改**且在 CI 内通过——它的 (b) 判据是"框内存在明显暗于内容色的像素"，半透黑圆底叠在 `white 0.1` 内容上约为 11（内容 25），仍满足 `亮度 + 8 < 内容亮度`（闸门 C 未触发） |

**以上全部标注「夹具驱动，真机未覆盖」。** C 系列虽然走的是真实 `S2TemporaryPhotoImageView` 与真实的 `.assetChange` / `.pinchEnded` 触发路径，但图像来自脚本化假策略而不是 PhotoKit；D 系列是 `ImageRenderer` 离屏位图，不是真机屏幕。

## 闸门

| 闸门 | 状态 | 说明 |
|---|---|---|
| A R1 须改 `S2ImageRequestStrategy` 结构 / 请求发起时机 / 节流 | **未触发** | 三者一行未改。`S2ImageRequestStrategy`、`S2ImageRequestDecision.shouldRequest`、`requestKey(for:)`、`requestImageIfNeeded` 全部原样；R1 只在"返回结果是否上屏"这一处插入判定 |
| B 任一既有门禁失败 | **未触发** | |
| C 两处标记的既有测试需要削弱才能通过 | **未触发** | `git diff 420e72a..HEAD -- PhotoCleanupMVETests/` 的删除行只有 `renderStrip` 的形参声明与其上两行注释（替换为含 `colorScheme` 形参的新签名，默认 `.light`，既有调用点行为不变）。G181、G180、两个 `symbolName` 断言、脉冲与显示条件断言全部一字未改 |
| D 须新增标定参数 / 改出厂值 / `schemaVersion` | **未触发** | `S2Calibration.swift` 整体 `git diff` 为空，`schemaVersion` 保持 4。R2 的两个色值是固定渲染常量，不进配置也不进登记表 |

## CI 与本地门禁

| 项 | 值 |
|---|---|
| 运行编号 | **CI #162**（id `32795064582`），工作流「iOS 构建与自验」 |
| 结论 | **success**，9 步全部 success |
| 被测提交（完整 SHA） | `c2be235dad092e3819dc8fbcccadf076f5eab893` |
| XCTest 项数 / 失败数 | `Executed 492 tests, with 0 failures (0 unexpected) in 38.721 (60.842) seconds`；`** TEST SUCCEEDED **` |
| 真实退出码 | `test_status=0`；工作流以 `set -o pipefail` 采集并 `exit "$test_status"` 原样退出 |
| IPA 字节数 | **786812** |
| IPA SHA-256 | `f561d1ade34cb938af8d6b92c7432f918286d0c202af19233f661f7ca21a9850`（CI 报告值） |
| IPA 本地复核 | artifact `PhotoCleanupMVE-unsigned-c2be235dad09` 下载解出 786812 字节，本地 `sha256sum` 与 CI 报告值**一致** |

前一次 **CI #161**（id `32794588670`，被测 `0bc8401`）：failure，`Executed 492 tests, with 2 failures`，`构建未签名应用` 与 `上传 IPA` 两步 skipped。两条失败都是本卡自己新增的断言写错（见上文「CI #161 暴露的两条」），产品代码未动；**R1 的 C1～C5、R2 的 D1～D3、事件断言与全部既有门禁在 #161 里就已通过**。

本地门禁（Windows，本机无 Xcode，无法执行 XCTest 或构建 IPA）：

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（目录条目 171 / 产品源码引用 key 171、用户可见硬编码残留 **0**） |
| `git diff --check` | **0** |

## 人工判定项（保留给 Lynn，本报告不代为下结论）

**H39**（装本卡 CI 包，CI #162 的 artifact `PhotoCleanupMVE-unsigned-c2be235dad09`）：捏合放大松手、双击放大 / 缩小——不再有"清晰 → 糊 → 清晰"的闪替；可开场景 C 复录一段（导出里应看到 `图片替换被抑制`、`candidate` 明显小于 `displayed`，而**没有**对应的降质 `图片替换`）；首次进入未缓存照片仍先见降质图快速上屏（H27 不回归）。

**H40**：深色与浅色模式下，横栏与主图的待删标记均清晰可见、两模式观感一致；标记不被圆角裁掉。若圆底透明度观感不合适，只反馈"偏深 / 偏浅"。

## 真机未覆盖项清单

1. **闪替是否真的消失**——本卡的全部价值所在。夹具证明的是"更小的结果不上屏"，证明不了真机上 PhotoKit 的交付序列里没有别的降质路径绕过这一处。判据：H39 的场景 C 复录。
2. **PhotoKit 返回图的 `scale` 是否恒为 1**。产品用 `点尺寸 × scale` 计算像素尺寸，因此即便 `scale ≠ 1` 判定也正确；但既有 `图片替换` 事件的 `pixel=` 用的是 `image.size`（点尺寸），若真机上 `scale ≠ 1`，两个事件的口径会不一致。夹具里 PhotoKit 不参与，未覆盖。
3. **首次加载不回归**（H27）——C2 / C3 只在假策略上验证了"资产切换与首次显示不受限"。
4. **iCloud 按需下载路径**：网络下载期间的多次降质交付在真机上才有；若下载过程中反复交付逐步变大的预览，本判定会让它们逐级上屏（每一级都不小于前一级），符合预期，但未实测。
5. **深色 / 浅色下标记的真机观感**（H40）——`ImageRenderer` 离屏位图不等于真机屏幕（色彩管理、材质背景、Display P3）。
6. **圆底 0.55 是否合适**——④取定值，H40 只收"偏深 / 偏浅"。
7. **主图标记在 `S2View` 浮层里的实际呈现**：D2 渲染的是两处共用的 `S2PendingDeletionMark` 本身，不是 `primaryMarkOverlay` 的完整浮层（位置、脉冲、安全区 padding 由既有断言与 H40 覆盖）。
8. **标记叠在各种照片内容上的可读性**：夹具背景是纯中灰，真机是任意照片。

## 发现但未处理的问题（按纪律只报告不修）

1. **`图片替换` 与 `图片替换被抑制` 两个事件的像素口径不一致。** 前者用 `record.pixelSize = result.image?.size`（**点**尺寸），后者用 `S2ImageUpgradeDecision.pixelSize`（点尺寸 × `scale`）。PhotoKit 的 `scale == 1` 时两者数值相同，因此当前不产生分歧；但这是一处潜在的口径漂移。改 `图片替换` 的口径会动 IC-090 的既有事件格式，超出本卡范围，未动。
2. **判据是面积而不是逐边，且两者在真实照片尺寸上会分岔。** 见上文"R1"节与 CI #161 那节。`4032×3024`（12 192 768）小于 `3060×4080`（12 484 800），按面积会被拦下，按"逐边都不小于"也会被拦下（3024 < 4080）；但 `50×300` 相对 `100×100` 按面积放行、按逐边会被拦下。C0 用两条断言把两种情形都钉住了。卡内写的是"像素尺寸（宽×高）"，按面积理解；若要的是逐边，一行可改。
3. **`S2ImageLoadStateRegistry` 不记录抑制。** 被抑制的结果仍会经 `onRequestResult` 更新 `imageRequestResult` 逐帧字段（那是"最近一次请求返回了什么"，与是否上屏无关，本就该记），但 `lastImageReplacement` 不变——符合"不产生 `图片替换` 事件"的要求。若技术负责人希望逐帧字段也能看出"这一帧有结果返回但被拦下"，需要新增字段，本卡未做。
4. **横栏缩略图路径也走同一判定。** `stripItemContent` 用的也是 `S2TemporaryPhotoImageView`，因此横栏缩略图同样只升不降。卡内定案文字没有区分主图与横栏，按"同一资产已有已显示图像"的字面实现，未加区分。横栏请求尺寸恒定（`requestedScale: 1`、`requestRevision: 0`），实际上不会出现同资产的多次不同尺寸请求，因此预期无影响。
5. **`Color.black.opacity(0.55)` 在深色模式下不做任何适配。** 这是本卡定案要的（固定色值），但它意味着：如果将来照片区背景改成深色材质，标记圆底与背景的对比会下降。规格口径已按卡记为决策 24 的例外，随 v16 修订。
6. **D2 覆盖的是共用视图而不是主图浮层本身。** 见"真机未覆盖项"第 7 条。要端到端覆盖需要在夹具里渲染整个 `S2View`（需要 machine + calibration + coordinator），成本远高于收益，未做。
7. **`renderStrip` 的 `colorScheme` 形参默认 `.light`。** 既有调用点因此行为不变，但这也意味着 IC-085 / IC-090 的既有像素门禁只在浅色下取证。若将来要求所有横栏像素门禁都双模式取证，需要逐条加参数，本卡未扩大范围。
