//
//  AppIconManager.swift
//  CougarQuest
//
//  Wraps UIApplication's alternate-icon API and tracks the currently-selected
//  icon as a published value so SwiftUI can drive a picker UI off it.
//

import SwiftUI
import UIKit

/// One option the user can pick. The `name` is what UIKit uses to resolve
/// the `.icon` bundle (matches the entry in Info.plist's
/// `CFBundleAlternateIcons` and the `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
/// build setting). Use `nil` to mean "the primary app icon."
struct AppIconOption: Identifiable, Hashable {
    let id: String
    /// The internal name UIKit uses; `nil` for the primary icon.
    let assetName: String?
    /// The user-facing label.
    let displayName: String
    /// A small preview image to show in the picker. Optional — falls back
    /// to a label-only card if the bundle doesn't contain this asset yet.
    let previewAssetName: String?

    static let primary = AppIconOption(
        id: "primary",
        assetName: nil,
        displayName: "Default",
        previewAssetName: "AppIconPreview"
    )

    static let vintage = AppIconOption(
        id: "CougarQuestVintage",
        assetName: "CougarQuestVintage",
        displayName: "Vintage",
        previewAssetName: "VintagePreview"
    )

    static let all: [AppIconOption] = [.primary, .vintage]
}

@MainActor
final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()

    @Published private(set) var current: AppIconOption

    private init() {
        let activeName = UIApplication.shared.alternateIconName
        self.current = AppIconOption.all.first(where: { $0.assetName == activeName }) ?? .primary
    }

    func select(_ option: AppIconOption) async {
        // No-op when the user picks the icon that's already active.
        guard option.assetName != UIApplication.shared.alternateIconName else { return }

        // Some iOS versions throw if alternate icons aren't supported (e.g. on
        // CarPlay-only or on older devices); guard accordingly.
        guard UIApplication.shared.supportsAlternateIcons else {
            print("‼️ alternate icons not supported on this device")
            return
        }

        do {
            try await UIApplication.shared.setAlternateIconName(option.assetName)
            current = option
        } catch {
            print("‼️ setAlternateIconName failed:", error.localizedDescription)
        }
    }
}
