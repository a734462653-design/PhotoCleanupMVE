// IC-165 A（裁定 五）：首页展开卡 → 类别页页头的 zoom 过渡，从类别页文件原样抽出（系统版本判定只在本文件）。
import SwiftUI

/// 首页展开卡的过渡源。iOS 18 起首页那张卡放大成类别页页头；iOS 17 走默认 push。
struct S0DeckZoomSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

/// 类别页的过渡目的地。与 `S0DeckZoomSource` 同一 `id` 才配得上。
struct S0DeckZoomDestination: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
