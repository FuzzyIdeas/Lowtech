import Foundation
import SwiftUI

// MARK: - ChildSizeReader

struct ChildSizeReader<Content: View>: View {
    @Binding var size: CGSize

    let content: () -> Content

    var body: some View {
        content().background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SizePreferenceKey.self,
                    value: proxy.size
                )
            }
        )
        .onPreferenceChange(SizePreferenceKey.self) { preferences in
            self.size = preferences
        }
    }
}

// MARK: - SizePreferenceKey

struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize

    static var defaultValue: Value = .zero

    static func reduce(value _: inout Value, nextValue: () -> Value) {
        _ = nextValue()
    }
}

extension AnyView {
    var state: State<Self> { State(initialValue: self) }
}

extension ExpressibleByNilLiteral {
    var state: State<Self> { State(initialValue: self) }
}

extension Color {
    var state: State<Self> { State(initialValue: self) }
}

extension BinaryInteger {
    var state: State<Self> { State(initialValue: self) }
}

extension FloatingPoint {
    var state: State<Self> { State(initialValue: self) }
}

extension AnyHashable {
    var state: State<Self> { State(initialValue: self) }
}

func st<T>(_ v: T) -> State<T> {
    State(initialValue: v)
}
