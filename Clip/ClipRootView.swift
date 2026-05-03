//
//  ClipRootView.swift
//  Clip
//

import SwiftUI
import StoreKit

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
