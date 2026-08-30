# IC-115 自验报告：放大自动隐藏续做——**停线，链条中止**

## 结论（先行）

**IC-115 未绿，触发「两者都不是 → 停」。IC-116、IC-117 未开工。**

- **当时最新绿 tip** = `7fa94b1`（IC-114 子项 C），CI **#220**，**570 项 0 失败**，IPA 990596 字节，SHA-256 `3b4328024d1b4c263f609cb36991197120682fb7e055d5fcc92c64aa867deeb9`。
- **分支当前 tip** = `ba3213b`（IC-115，**红**，CI #222）。
- 进展：#221 的 **30 失败 / 8 用例** → #222 的 **21 失败 / 1 用例**。**七条已按裁定改写或修复并绿**，只剩 `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`。
- 停线成因**不是测试问题**：⑤a 与既有「截图沉浸推迟应用」（IC-104 C / v17 决策 40，177/180 行族）**在 Nx 截图上互相矛盾**，该诊断阶段**在构造上不可达**，改任何期望值都救不了。**这正是卡内 D2 预核第 3 条断言「不受影响」的那条机制——预核在此处被推翻。**
- CI 用 **1/2**（余 1 未用——因为剩下的不是能靠再试一次解决的问题）。
- `schemaVersion == 7`、登记值、冻结三链、`ci.yml`、`Scripts/` **零改动**；未合并 `main`。

---

## #221 八个失败用例的逐一归类（卡内要求）

### 旧契约 → 授权改写（6 条，**均已改写并在 #222 转绿**）

| 用例 | 处置 |
|---|---|
| `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | 更名 `testK2DoubleTapAutoHidesOnEnterAndRestoresOnExit`，按新契约改写；「到达目标倍率」那一半未动 |
| `testIC047_004TransitionRowDoubleTap` | 转移表双击行按新契约 |
| `testIC047_037DoubleTapEnterAndExitRestoresVisibility` | 恢复语义现在非平凡（此前进出都不改 V，断言是恒等式），并补「记录值不被 Nx 单击改写」 |
| `testE2ReplacementDoubleTapSuppressesSingleTapAction` | 同属「双击后 V 不变」旧契约。改用**隐藏态起手**区分「单击动作误触发」与「⑤a 自动隐藏」——本意保留且更锋利 |
| `testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap` | 同上 |
| `testIC047_035PinchExclusivelyOwnsTouchSequence` | 落点 `visibleNx` → `hiddenNx`；该用例考的「捏合独占触摸序列」语义未变 |

**转移表的处理**：产品侧 `transitionRule` 是**只被测试引用**的声明式镜像（唯一调用点在 `S2StateMachineTests`），不在运行时路径。新契约下两条进入行落点确定（一律 `hiddenNx`），但**两条退出行的落点取决于记录的进入前 V、不是原状态的函数**，故与捏合行一样标 `conditional(.dynamic)`。

### D 自身缺陷 → 修 D（2 条）

| 用例 | 处置 | 结果 |
|---|---|---|
| `testIC114DScaleChangesWithinZoomDoNotTouchVisibility` | **本卡自己的用例有 bug**：捏合期间 `touchSequenceOwner == .pinch`，`handleSingleTap` 被 `receivesUnobscuredInput` 挡下（这是 IC047-035 的既有语义、非缺陷），是我在捏合未结束时就单击。改为先 `endPinch` 再单击 | **已绿** |
| `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` | 首轮判为「诊断脚本把旧契约写死」，把 `startDoubleTapEntry` 的稳定态由 `(V=显示, Nx)` 改为 `(V=隐藏, Nx)` | **仍红——判断只对了一半，真因见下** |

### 未触碰

132 条隐藏态手势断言、其他显隐断言、`testIC047_036`（捏合不越过 1x，故不触发 ⑤a）一律未改。

---

## 停线根因：⑤a 与「截图沉浸推迟应用」在 Nx 截图上互斥（①）

四条代码实据，逐条可核：

1. **`applyPage` 里 V 驱动的呈现变更在放大态被推迟**（`S2NativePhotoPager.swift`）：
   ```swift
   let presentationChanged = sameAsset &&
       interfaceVisibility != page.interfaceVisibility &&
       isFramedPhoto && page.isFramedPhoto &&
       (fittedSize != page.fittedSize || cornerRadius != page.cornerRadius)
   let nativeZoomIsAboveOne = isCurrent && zoomScrollView.zoomScale > 1.000_001
   if scale > 1.000_001 || nativeZoomIsAboveOne {
       if presentationChanged {
           pendingPresentationPage = page
           lastPresentationTransitionDuration = 0
           return            // ← 直接返回，页面侧 interfaceVisibility 不落地
       }
   ```
2. **推迟的呈现只在回到 1x 才应用**：`applyDeferredPresentationIfPossible` 的守卫含 `zoomScrollView.zoomScale <= 1.000_001`。
3. **诊断的稳定判据要求机器侧与页面侧同时等于期望值**：
   ```swift
   if machine.interfaceVisibility == visibility,
      machine.zoomState == zoomState,
      page.diagnosticInterfaceVisibility == visibility,   // ← 页面侧
      !page.isPresentationTransitionActive,
      !page.isDoubleTapTransitionActive,
      zoomMatches { completion(true) }
   ```
   而 `diagnosticInterfaceVisibility` 直接返回控制器自己的 `interfaceVisibility`。
4. **该诊断用例强制截图**：`assetIsScreenshot: { _ in true }`，故 `isFramedPhoto` 成立；截图的显示态/隐藏态几何本就不同（v17 决策 40），故 `presentationChanged` 成立。

**合起来**：⑤a 让 V 在**进入放大的同一瞬间**变为隐藏；但第 1、2 条决定页面侧的隐藏态在 Nx 期间**永远不落地**。于是在 Nx 的截图上——

> **机器侧说「隐藏」，页面侧说「显示」。**

第 3 条要求两者同时等于同一个期望值，故：
- 期望写 `.hidden`（新契约、机器侧为准）→ 页面侧不满足；
- 期望写 `.visible`（页面侧为准）→ 机器侧不满足。

**没有任何期望值能让这一阶段稳定**——它在构造上不可达。这不是断言写错，也不是我能在授权范围内修好的 D 缺陷。

### 为什么按「两者都不是 → 停」

要让它可达，只有三条路，**每一条都是产品/规格决策**：

- **(a)** 放宽 `applyDeferredPresentationIfPossible` 的 `zoomScale <= 1` 守卫，让「只改 V」的呈现变更在放大态也应用——直接动 IC-104 C / v17 决策 40 的推迟应用契约。
- **(b)** 把诊断的稳定判据改为只看机器侧——**弱化一条门禁去凑绿**，与 IC-117「不得调探针阈值凑绿」同源，方法学决策。
- **(c)** 修订 ⑤a 本身（例如改为退出时才切 V，或对截图豁免）。

三者都超出执行端权限，故停，**未动上述任何一处**。

### 连带的产品影响（非仅诊断，须决策会话知悉）

这不是只在诊断里发作的现象。真机上对**截图**资产：进入放大后状态机 `V=隐藏`（chrome 浮层确实会隐藏，因为它由 `machine.interfaceVisibility` 直接驱动），但**页面侧仍按显示态的截图几何渲染**，直到退出放大才应用隐藏态几何。是否可接受，属产品判定。非截图资产不受影响（`presentationChanged` 要求 `isFramedPhoto`）。

---

## 本地门禁（①）

提交前三门禁全部退出码 0：`git diff --check`、`Scripts/selfcheck.ps1`、`Scripts/scan-hardcoded-user-visible-strings.ps1`。

---

## 后续卡状态

- **IC-116（Xcode 26 工具链）**：**未开工**（开工条件是 IC-115 绿）。
- **IC-117（Liquid Glass）**：**未开工**。
- 顺带留一条 IC-116 的备料（本次为定位 A1 而实证，①，可直接用）：runner `macos-15` 上 `xcodebuild -version` 为 **Xcode 16.4（Build 16F6）**，而 `simctl` 列出 **iOS 26.0 / 26.1 / 26.2** 运行时——镜像上存在 Xcode 26，只是未被选中。IC-116 写路径前仍应按卡内要求先 `ls /Applications | grep Xcode` 实证。

---

## 停线 / 偏差 / 待补核

### 停线
- **IC-115「两者都不是 → 停」**：**已触发**，成因如上。CI 用 1/2，余 1 未用——剩下的不是靠再试一次能解决的问题。

### 偏差
- 首轮把 IC-063 判为「诊断脚本写死旧契约」并改了稳定态期望。**该判断只对了一半**：脚本确实写着旧契约，但改对之后仍不可达，真因在推迟应用机制。该改动已保留在提交里（新契约下它本就该是 `.hidden`），不影响后续处置。

### 待补核
1. **D2 预核第 3 条被推翻**：「截图沉浸推迟应用（177/180 行族）不受影响」不成立。
2. 上述 (a)/(b)/(c) 三条路线需决策会话择一；选定后 IC-115 只差把该阶段改到可达即可转绿，六条已改写门禁无需再动。
3. IC-114 遗留的两项待补核仍有效（A3 静止态是否影响玻璃透光；Nx 期间手动切 V 后退出是否应按记录值恢复）。
