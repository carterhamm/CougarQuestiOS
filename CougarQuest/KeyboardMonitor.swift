import SwiftUI
import Combine
import UIKit

/// App-wide keyboard visibility tracker. Use as @ObservedObject in any view
/// that needs to react to keyboard show/hide. More reliable than per-view
/// .onReceive because the singleton is wired up at app launch.
final class KeyboardMonitor: ObservableObject {
    static let shared = KeyboardMonitor()
    @Published var isVisible: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let nc = NotificationCenter.default
        Publishers.Merge(
            nc.publisher(for: UIResponder.keyboardWillShowNotification).map { _ in true },
            nc.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in false }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] visible in
            self?.isVisible = visible
        }
        .store(in: &cancellables)
    }
}
