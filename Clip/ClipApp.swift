//
//  ClipApp.swift
//  Clip (CougarQuest App Clip)
//
//  One-screen quest preview with a "Get the full app" CTA.
//  Reads the quest by id from Firestore based on the invoking URL.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct CougarQuestClipApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ClipRootView()
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL,
                       let id = CougarQuestLink.questId(from: url) {
                        ClipState.shared.questId = id
                    }
                }
        }
    }
}

/// Holds the quest id parsed from the invocation URL. Updated either on
/// app launch (from the universal-link continuation) or via SwiftUI's
/// .onContinueUserActivity callback above.
final class ClipState: ObservableObject {
    static let shared = ClipState()
    @Published var questId: String? = nil
    @Published var quest: ClipQuest? = nil
    @Published var loadError: String? = nil
    private init() {}

    func loadQuest(id: String) {
        Firestore.firestore().collection("quests").document(id).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    self.loadError = error.localizedDescription
                    return
                }
                guard let data = snapshot?.data() else {
                    self.loadError = "Quest not found."
                    return
                }
                self.quest = ClipQuest(
                    id: id,
                    title: data["title"] as? String ?? "",
                    address: data["address"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    photoURL: data["photoURL"] as? String ?? "",
                    mapsLink: data["mapsLink"] as? String ?? ""
                )
            }
        }
    }
}

/// Lightweight Quest type for the clip — no @DocumentID, no Codable
/// gymnastics, just the fields the preview screen needs.
struct ClipQuest: Identifiable, Equatable {
    let id: String
    let title: String
    let address: String
    let description: String
    let photoURL: String
    let mapsLink: String
}
