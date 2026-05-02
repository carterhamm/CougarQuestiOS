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
import Kingfisher

final class TabPresentationStore: ObservableObject {
    static let shared = TabPresentationStore()
    @Published var selectedTab: TabItem = .home
    @Published var selectedQuest: Quest? = nil
    @Published var isHomeQuestOpen: Bool = false
    private init() {}
}

enum TabItem: CaseIterable, Identifiable, Hashable {
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
    @ObservedObject var tabStore = TabPresentationStore.shared
    @Namespace private var animation
    @State private var dragOffset: CGFloat = 0
    @State private var sheetQuest: Quest? = nil
    @State private var pillDragX: CGFloat? = nil
    @State private var isPillDragging: Bool = false

    private var capsuleHeight: CGFloat {
        (tabStore.selectedTab == .quests && tabStore.selectedQuest != nil)
            ? UIScreen.main.bounds.height * 0.36
            : 68
    }

    private func dismissExpanded() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            tabStore.selectedQuest = nil
            dragOffset = 0
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(height: capsuleHeight)
                .adaptiveGlassEffect(in: RoundedRectangle(cornerRadius: 50))
                .allowsHitTesting(false)

            if tabStore.selectedTab == .quests, let quest = tabStore.selectedQuest {
                expandedQuestContent(quest: quest)
                    .frame(height: capsuleHeight - 80, alignment: .top)
                    .offset(y: -70 + dragOffset)
            }

            GeometryReader { geo in
                let tabs = TabItem.allCases
                let cellWidth = (geo.size.width - 12) / CGFloat(tabs.count)
                let restingX = 6 + cellWidth * CGFloat(tabs.firstIndex(of: tabStore.selectedTab) ?? 0)
                let pillX: CGFloat = {
                    if let x = pillDragX {
                        return min(max(x - cellWidth / 2, 6), geo.size.width - 6 - cellWidth)
                    }
                    return restingX
                }()

                ZStack(alignment: .leading) {
                    Color.clear
                        .frame(width: cellWidth, height: 56)
                        .adaptiveGlassEffectTinted(color: Color.cougarBlue.opacity(0.9), in: RoundedRectangle(cornerRadius: 50))
                        .scaleEffect(isPillDragging ? 0.92 : 1)
                        .shadow(color: Color.cougarBlue.opacity(isPillDragging ? 0.5 : 0.25), radius: isPillDragging ? 24 : 15, x: 0, y: 5)
                        .offset(x: pillX)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.75), value: pillX)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: tabStore.selectedTab)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPillDragging)

                    HStack(spacing: 0) {
                        ForEach(TabItem.allCases) { tab in
                            VStack(spacing: 2) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(tab.title)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(tabStore.selectedTab == tab ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 68)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                                if tab != .quests { tabStore.selectedQuest = nil }
                                if tab != .home { tabStore.isHomeQuestOpen = false }
                                withAnimation { tabStore.selectedTab = tab }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            if !isPillDragging {
                                isPillDragging = true
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                            pillDragX = value.location.x
                            let index = Int(round((value.location.x - 6 - cellWidth / 2) / cellWidth))
                            let clamped = max(0, min(tabs.count - 1, index))
                            if tabs[clamped] != tabStore.selectedTab {
                                tabStore.selectedTab = tabs[clamped]
                                let generator = UIImpactFeedbackGenerator(style: .soft)
                                generator.impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isPillDragging = false
                                pillDragX = nil
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                )
            }
            .frame(height: 68)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func expandedQuestContent(quest: Quest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 50, height: 5)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { dismissExpanded() }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 50 {
                            dismissExpanded()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            ZStack(alignment: .bottomLeading) {
                if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .clipped()
                } else {
                    Color.gray.opacity(0.3)
                        .frame(height: 96)
                }
                LinearGradient(
                    colors: [Color.black.opacity(0.65), Color.clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(quest.address)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(12)
            }
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(quest.description)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    sheetQuest = quest
                } label: {
                    Text("View Quest")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.cougarBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .adaptiveGlassEffectTinted(color: Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)

                if let url = URL(string: quest.mapsLink) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text("Navigate")
                        }
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .adaptiveGlassEffectTinted(color: Color.cougarBlue.opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .sheet(item: $sheetQuest) { q in
            NavigationStack {
                QuestView(quest: q)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var tabStore = TabPresentationStore.shared
    @State private var selectedTabLocal: TabItem = .home
    @State private var isHomeQuestOpenLocal: Bool = false
    @State private var isKeyboardVisible: Bool = false
    @State private var showActionButtons: Bool = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var imageToUpload: UIImage?

    private let islandAnimation = Animation.spring(response: 0.65, dampingFraction: 0.65, blendDuration: 0.85)

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
                    tabStore.isHomeQuestOpen = false
                    tabStore.selectedQuest = nil
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        TabView(selection: $selectedTabLocal) {
            NavigationStack {
                HomeView()
            }
            .tag(TabItem.home)

            NavigationStack {
                QuestsView()
            }
            .tag(TabItem.quests)

            NavigationStack {
                LeaderboardView()
            }
            .tag(TabItem.leaderboard)

            NavigationStack {
                if profileVM.isAdmin {
                    SortingView()
                } else {
                    ProfileView()
                }
            }
            .tag(TabItem.profile)
        }
        .onAppear {
            UITabBar.appearance().isHidden = true
        }
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        let _ = print("📍 bottomOverlay recompute: selectedTabLocal=\(selectedTabLocal), isHomeQuestOpenLocal=\(isHomeQuestOpenLocal), showActionButtons=\(showActionButtons)")
        let fullWidth = UIScreen.main.bounds.width - 40
        let safeArea = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom }
            .first ?? 15

        if selectedTabLocal == .home {
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: isHomeQuestOpenLocal ? 68 : fullWidth, height: 68)
                        .adaptiveGlassEffect(in: RoundedRectangle(cornerRadius: 40))
                        .allowsHitTesting(false)
                        .padding(.horizontal, 20)
                        .padding(.bottom, safeArea * 0.3)
                        .offset(y: 26)
                        .animation(islandAnimation, value: isHomeQuestOpenLocal)
                    Spacer()
                }
                if isHomeQuestOpenLocal && showActionButtons {
                    let buttonSize: CGFloat = 68
                    let spacing: CGFloat = 12
                    let cameraWidth = fullWidth - (buttonSize * 2) - (spacing * 2)
                    HStack(spacing: spacing) {
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            withAnimation(islandAnimation) { tabStore.isHomeQuestOpen = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Color(UIColor { trait in
                                    trait.userInterfaceStyle == .dark ? .white : UIColor(named: "CougarBlue") ?? .blue
                                }))
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            imagePickerSource = .photoLibrary
                            showImagePicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Color(UIColor { trait in
                                    trait.userInterfaceStyle == .dark ? .white : UIColor(named: "CougarBlue") ?? .blue
                                }))
                                .frame(width: buttonSize, height: buttonSize)
                                .adaptiveGlassEffect(in: Circle())
                        }
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            imagePickerSource = .camera
                            showImagePicker = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: cameraWidth, height: buttonSize)
                                .adaptiveGlassEffectTinted(color: .cougarBlue, in: RoundedRectangle(cornerRadius: 40))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, safeArea * 0.3)
                    .offset(y: 26)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
                FloatingTabBar()
                    .padding(.bottom, safeArea * 0.3)
                    .offset(y: 26)
                    .opacity(isHomeQuestOpenLocal ? 0 : 1)
                    .animation(islandAnimation, value: isHomeQuestOpenLocal)
            }
        } else {
            FloatingTabBar()
                .padding(.bottom, safeArea * 0.3)
                .offset(y: 26)
                .animation(islandAnimation, value: selectedTabLocal == .quests && tabStore.selectedQuest != nil)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
            bottomOverlay
                .zIndex(100)
        }
        .onReceive(tabStore.$selectedTab) { newTab in
            print("📡 onReceive selectedTab → \(newTab) (isHomeQuestOpen=\(tabStore.isHomeQuestOpen))")
            if tabStore.isHomeQuestOpen && newTab != .home {
                print("📡 ignoring phantom tab change during morph")
                tabStore.selectedTab = .home
                return
            }
            selectedTabLocal = newTab
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onReceive(tabStore.$isHomeQuestOpen) { open in
            print("🟡 onReceive isHomeQuestOpen → \(open) [before mirror: local=\(isHomeQuestOpenLocal)]")
            isHomeQuestOpenLocal = open
            print("🟦 isHomeQuestOpenLocal is now \(isHomeQuestOpenLocal)")
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
                tabStore.selectedQuest = nil
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                source: imagePickerSource == .camera ? .camera : .library,
                image: $imageToUpload
            )
        }
        .onChange(of: imageToUpload) { image in
            if let quest = tabStore.selectedQuest, let img = image {
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
