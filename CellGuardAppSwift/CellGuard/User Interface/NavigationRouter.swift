import SwiftUI

/// Own one router per navigation stack so tabs and sheets keep independent paths.
@MainActor
final class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()

    func push<Value: Hashable>(_ value: Value) {
        path.append(value)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}

/// A standalone stack that supplies programmatic navigation to its descendants.
struct CGNavigationStack<Content: View>: View {
    @StateObject private var navigator = NavigationRouter()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $navigator.path) {
            content
        }
        .environmentObject(navigator)
    }
}
