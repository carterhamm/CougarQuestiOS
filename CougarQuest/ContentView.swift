//
//  ContentView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/23/25.
//

import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

enum TabItem: CaseIterable, Identifiable {
    case home, quests, leaderboard, profile
    var id: Self { self }
    var title: String {
        switch self {
        case .home:        return "Home"
        case .quests:      return "Quests"
        case .leaderboard: return "Standings"
        case .profile:     return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .home:        return "house.fill"
        case .quests:      return "map.fill"
        case .leaderboard: return "chart.bar.fill"
        case .profile:     return "person.fill"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: TabItem
    @Binding var selectedQuest: Quest?
    @Namespace private var animation

    /// Capsule expands vertically; bottom edge fixed.
    private var capsuleHeight: CGFloat {
        (selectedTab == .quests && selectedQuest != nil)
            ? UIScreen.main.bounds.height * 0.35
            : 80
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1) Background capsule
            RoundedRectangle(cornerRadius: 50)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                )
                .frame(height: capsuleHeight)

            // 2) Quest info in the extra space above the bottom 80 pts
            if selectedTab == .quests, let quest = selectedQuest {
                VStack(alignment: .leading, spacing: 8) {
                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundColor(Color.gray.opacity(0.5))
                        .offset(y: -15)
                        .frame(maxWidth: .infinity)
                        // Tap or drag to collapse
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation { selectedQuest = nil }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { _ in
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    withAnimation { selectedQuest = nil }
                                }
                        )

                    VStack(alignment: .leading, spacing: 10) {
                        Text(quest.title)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(quest.description)
                            .font(.body)
                            .lineLimit(3)
                        
                        if let url = URL(string: quest.mapsLink) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Text("Open in Maps")
                                    Image(systemName: "map.fill")
                                }
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.cougarBlue)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 9)

                    Spacer()
                }
                .padding()
                // Restrict to only the new “headroom” and align at its top
                .frame(height: capsuleHeight - 80, alignment: .top)
                // shift up so it's closer to the capsule’s top edge
                .offset(y: -70)
            }

            // 3) White pill + icons/titles locked into the bottom 80 pts
            ZStack(alignment: .leading) {
                // White pill behind current tab
                GeometryReader { geo in
                    let tabs = TabItem.allCases
                    let cellWidth = (geo.size.width - 25) / CGFloat(tabs.count)
                    RoundedRectangle(cornerRadius: 50)
                        .fill(Color.white)
                        .frame(width: cellWidth, height: 60)
                        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
                        .offset(x: 12 + cellWidth * CGFloat(tabs.firstIndex(of: selectedTab) ?? 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedTab)
                }
                .frame(height: 60)

                // Icons & titles
                HStack(spacing: 0) {
                    ForEach(TabItem.allCases) { tab in
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            withAnimation { selectedTab = tab }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(tab.title)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(selectedTab == tab ? .cougarBlue : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

struct ContentView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab: TabItem = .home
    @State private var isKeyboardVisible: Bool = false
    @State private var selectedQuest: Quest? = nil
    @State private var isHomeQuestOpen: Bool = false
    @State private var showActionButtons: Bool = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var imageToUpload: UIImage?

    // MARK: - Upload helper
    private func uploadPhoto(_ image: UIImage, for quest: Quest) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let path = "\(uid)/\(quest.id ?? quest.title)/photo.png"
        let ref = Storage.storage().reference().child(path)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        ref.putData(data, metadata: nil) { _, error in
            if let error = error {
                print("‼️ upload failed:", error.localizedDescription)
                return
            }
            let userRef = Firestore.firestore().collection("users").document(uid)
            Firestore.firestore().runTransaction({ txn, _ in
                txn.updateData(
                    ["completedQuests": FieldValue.arrayUnion([quest.title])],
                    forDocument: userRef
                )
                let reward = Date().timeIntervalSince(quest.createdAt ?? Date()) <= 12*3600 ? 10 : 5
                txn.updateData(["points": FieldValue.increment(Int64(reward))],
                               forDocument: userRef)
                return nil
            }) { _, err in
                if let err = err {
                    print("‼️ firestore tx:", err.localizedDescription)
                }
            }
            DispatchQueue.main.async {
                imageToUpload = nil
                withAnimation {
                    isHomeQuestOpen = false
                    selectedQuest = nil
                }
            }
        }
    }

    // Spring animation for capsule height changes
    private let islandAnimation = Animation.spring(response: 0.65, dampingFraction: 0.65, blendDuration: 0.85)

    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                HomeView(isQuestOpen: $isHomeQuestOpen, selectedQuest: $selectedQuest)
            }
        case .quests:
            NavigationStack {
                QuestsView(selectedQuest: $selectedQuest)
            }
        case .leaderboard:
            LeaderboardView()
        case .profile:
            if profileVM.isAdmin {
                SortingView()
            } else {
                ProfileView()
            }
        }
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        let fullWidth = UIScreen.main.bounds.width - 40
        let safeArea = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom }
            .first ?? 15

        if selectedTab == .home {
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 40)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                        )
                        .frame(width: isHomeQuestOpen ? 80 : fullWidth, height: 80)
                        .padding(.horizontal, 20)
                        .padding(.bottom, safeArea)
                        .offset(y: 12)
                        .animation(islandAnimation, value: isHomeQuestOpen)
                    Spacer()
                }
                if isHomeQuestOpen && showActionButtons {
                    // ... copy only the HStack of buttons (restore, photo, camera) here ...
                    let buttonSize: CGFloat = 80
                    let spacing: CGFloat = 12
                    let cameraWidth = fullWidth - (buttonSize * 2) - (spacing * 2)
                    HStack(spacing: spacing) {
                        // 1) Restore...
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            withAnimation(islandAnimation) { isHomeQuestOpen = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 28))
                                .foregroundColor(Color(UIColor { trait in
                                    trait.userInterfaceStyle == .dark ? .white : UIColor(named: "CougarBlue") ?? .blue
                                }))
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        // 2) Photo library...
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            imagePickerSource = .photoLibrary
                            showImagePicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                                    )
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(UIColor { trait in
                                        trait.userInterfaceStyle == .dark ? .white : UIColor(named: "CougarBlue") ?? .blue
                                    }))
                            }
                            .frame(width: buttonSize, height: buttonSize)
                            .opacity(showActionButtons ? 1 : 0)
                            .offset(y: showActionButtons ? 0 : 20)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showActionButtons)
                        }
                        // 3) Camera...
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            imagePickerSource = .camera
                            showImagePicker = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: cameraWidth, height: buttonSize)
                        .background(
                            RoundedRectangle(cornerRadius: 40)
                                .fill(Color.cougarBlue)
                        )
                        .opacity(showActionButtons ? 1 : 0)
                        .offset(y: showActionButtons ? 0 : 20)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showActionButtons)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, safeArea)
                    .offset(y: 12)
                }
                FloatingTabBar(
                    selectedTab: $selectedTab,
                    selectedQuest: $selectedQuest
                )
                .padding(.bottom, safeArea)
                .offset(y: 12)
                .opacity(isHomeQuestOpen ? 0 : 1)
                .animation(islandAnimation, value: isHomeQuestOpen)
            }
        } else {
            FloatingTabBar(
                selectedTab: $selectedTab,
                selectedQuest: $selectedQuest
            )
            .padding(.bottom, safeArea)
            .offset(y: 12)
            .animation(islandAnimation, value: selectedTab == .quests && selectedQuest != nil)
        }
    }

    var body: some View {
        ZStack {
            // MARK: Main content
            mainContent
        }
        .overlay(bottomOverlay, alignment: .bottom)
        .onChange(of: selectedTab) { newTab in
            if newTab != .quests {
                selectedQuest = nil
            }
            if newTab != .home {
                isHomeQuestOpen = false
            }
        }
        // Keyboard handling
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        // Haptic feedback when a quest is selected
        .onChange(of: selectedQuest != nil) { hasQuest in
            if hasQuest {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
            }
        }
        .onChange(of: isHomeQuestOpen) { open in
            if open {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        showActionButtons = true
                    }
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showActionButtons = false
                }
                selectedQuest = nil // Clear selected quest when quest view is dismissed
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                source: imagePickerSource == .camera ? .camera : .library,
                image: $imageToUpload
            )
        }
        .onChange(of: imageToUpload) { image in
            if let quest = selectedQuest, let img = image {
                uploadPhoto(img, for: quest)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
            .environmentObject(ProfileViewModel())
            .previewDevice("iPhone 14")
    }
}
