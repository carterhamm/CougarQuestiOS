//
//  ClipRootView.swift
//  Clip
//

import SwiftUI
import StoreKit
import FirebaseFirestore

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

/// Holds the quest id parsed from the invocation URL. Updated either on
/// app launch (from the universal-link continuation) or via SwiftUI's
/// .onContinueUserActivity callback in ClipApp.
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

struct ClipRootView: View {
    @ObservedObject private var state = ClipState.shared
    @State private var showAppStoreOverlay = false

    var body: some View {
        ZStack {
            (Color(.systemGroupedBackground)).ignoresSafeArea()

            if let quest = state.quest {
                ClipQuestPreview(quest: quest, onGetApp: presentAppStoreOverlay)
            } else if let error = state.loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Get CougarQuest", action: presentAppStoreOverlay)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
            }
        }
        .appStoreOverlay(isPresented: $showAppStoreOverlay) {
            // Configures the App Store overlay for the *full* CougarQuest app.
            // Apple recommends overlaying after the user engages with the clip.
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
        .onAppear { tryLoad() }
        .onChange(of: state.questId) { _, _ in tryLoad() }
    }

    private func tryLoad() {
        guard let id = state.questId, state.quest == nil else { return }
        state.loadQuest(id: id)
    }

    private func presentAppStoreOverlay() {
        showAppStoreOverlay = true
    }
}
