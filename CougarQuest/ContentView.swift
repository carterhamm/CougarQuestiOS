//
//  ContentView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/23/25.
//

import SwiftUI
import UIKit
import AVFoundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Kingfisher

/// Routes incoming Universal Links / App Clip URLs into the running app.
/// `CougarQuestApp.swift`'s `.onOpenURL` writes here; `ContentView` observes
/// `pendingQuestId` and opens the matching quest.
final class DeepLinkState: ObservableObject {
    static let shared = DeepLinkState()
    @Published var pendingQuestId: String? = nil
    private init() {}

    func handle(_ url: URL) {
        let id = CougarQuestLink.questId(from: url)
        print("🔗 DeepLinkState.handle url=\(url.absoluteString) parsed id=\(id ?? "nil")")
        guard let id = id else { return }
        // Defer to the next runloop. Setting an @Published synchronously
        // inside .onOpenURL / .onContinueUserActivity sometimes loses the
        // change to SwiftUI's diff (it's still mid-update for the URL
        // delivery). A trailing dispatch makes the observation reliable.
        DispatchQueue.main.async { [weak self] in
            print("🔗 setting pendingQuestId = \(id)")
            self?.pendingQuestId = id
        }
    }
}

final class MorphState: ObservableObject {
    static let shared = MorphState()
    @Published var quest: Quest? = nil
    @Published var isUploading: Bool = false
    @Published var isComplete: Bool = false
    /// Titles of quests the current user has already completed.
    /// HomeView's snapshot listener populates this; the morph bar reads it
    /// to render the "Quest Complete!" state when the user re-opens a
    /// quest they previously finished.
    @Published var completedQuestTitles: Set<String> = []
    private init() {}

    /// True when the currently-open quest is one the user already finished.
    var isQuestAlreadyCompleted: Bool {
        guard let q = quest else { return false }
        return completedQuestTitles.contains(q.title)
    }
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
    @Binding var selectedTab: TabItem
    @Binding var selectedQuest: Quest?
    let onImagePicked: (UIImage) -> Void
    let onPresentQuestSheet: (Quest) -> Void
    @ObservedObject var morphState = MorphState.shared
    @Namespace private var animation
    @State private var dragOffset: CGFloat = 0
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var pickedImage: UIImage?

    private var isMorphActive: Bool {
        // Main floating bar only morphs on the HomeView path.
        // QuestsView path uses a sheet with its own MorphActionBar.
        selectedTab == .home && (morphState.quest != nil || morphState.isComplete)
    }

    private var capsuleHeight: CGFloat {
        // Expanded bar is ~12% taller than before so the hero photo can
        // breathe and the description can grow to multiple lines without
        // shoving the View Quest / Navigate buttons.
        (selectedTab == .quests && selectedQuest != nil)
            ? UIScreen.main.bounds.height * 0.40
            : 68
    }

    private func dismissExpanded() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            selectedQuest = nil
            dragOffset = 0
        }
    }

    private var isExpanded: Bool {
        selectedTab == .quests && selectedQuest != nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background pill — subtle CougarBlue tint when expanded so the
            // description text below has enough contrast to read against
            // arbitrary map content peeking through the glass.
            Color.clear
                .frame(height: capsuleHeight)
                .adaptiveGlassEffectTinted(
                    color: isExpanded ? Color.cougarBlue.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 50)
                )
                .allowsHitTesting(false)

            if selectedTab == .quests, let quest = selectedQuest {
                expandedQuestContent(quest: quest)
                    .frame(height: capsuleHeight - 80, alignment: .top)
                    // -80 (was -70) so the top of expandedQuestContent
                    // sits exactly at the top of the bar (no 10pt gap).
                    .offset(y: -80 + dragOffset)
                    .zIndex(1)
            }

            ZStack {
                tabContent
                    .opacity(isMorphActive ? 0 : 1)
                    .scaleEffect(isMorphActive ? 0.92 : 1)
                    .allowsHitTesting(!isMorphActive)
                morphContent
                    .opacity(isMorphActive ? 1 : 0)
                    .scaleEffect(isMorphActive ? 1 : 0.92)
                    .allowsHitTesting(isMorphActive)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isMorphActive)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                source: imagePickerSource == .camera ? .camera : .library,
                image: $pickedImage
            )
        }
        .onChange(of: pickedImage) { image in
            guard let img = image else { return }
            onImagePicked(img)
            pickedImage = nil
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        GeometryReader { geo in
            let tabs = TabItem.allCases
            let cellWidth = (geo.size.width - 12) / CGFloat(tabs.count)

            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: cellWidth, height: 56)
                    .adaptiveGlassEffectTinted(color: Color.cougarBlue.opacity(0.9), in: RoundedRectangle(cornerRadius: 50))
                    .shadow(color: Color.cougarBlue.opacity(0.25), radius: 15, x: 0, y: 5)
                    .offset(x: 6 + cellWidth * CGFloat(tabs.firstIndex(of: selectedTab) ?? 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedTab)

                HStack(spacing: 0) {
                    ForEach(TabItem.allCases) { tab in
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let raw = (value.location.x - 6) / cellWidth
                        let idx = max(0, min(tabs.count - 1, Int(raw.rounded())))
                        let target = tabs[idx]
                        if selectedTab != target {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedTab = target
                            }
                        }
                    }
            )
        }
        .frame(height: 68)
    }

    @ViewBuilder
    private var morphContent: some View {
        if morphState.isComplete || morphState.isQuestAlreadyCompleted {
            completeContent
        } else if morphState.isUploading {
            uploadingContent
        } else {
            captureContent
        }
    }

    @ViewBuilder
    private var captureContent: some View {
        let buttonSize: CGFloat = 56
        let spacing: CGFloat = 8
        HStack(spacing: spacing) {
            Button {
                print("❌ X tapped")
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                // Don't wrap in withAnimation — the NavigationStack pop has its own
                // .zoom transition that conflicts with an outer animation context.
                morphState.quest = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                print("📷 Photo library tapped")
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                imagePickerSource = .photoLibrary
                showImagePicker = true
                print("📷 showImagePicker now \(showImagePicker)")
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                print("📸 Capture tapped (button)")
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                requestCameraThenPresent()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                    Text("Capture")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: buttonSize)
                .adaptiveGlassEffectTinted(color: .cougarBlue, in: RoundedRectangle(cornerRadius: 28))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .frame(height: 68)
    }

    @ViewBuilder
    private var uploadingContent: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            Text("Uploading…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .padding(.horizontal, 6)
        .adaptiveGlassEffectTinted(color: .cougarBlue, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var completeContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("Quest Complete!")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .padding(.horizontal, 6)
        .adaptiveGlassEffectTinted(color: .cougarBlue, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap the complete pill to close the quest (no auto-dismiss for
            // re-opened completed quests — let the user leave on their schedule).
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.impactOccurred()
            morphState.quest = nil
        }
    }

    private func requestCameraThenPresent() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📸 Capture tapped, camera auth status: \(status.rawValue)")
        switch status {
        case .authorized:
            print("📸 authorized → opening camera")
            imagePickerSource = .camera
            showImagePicker = true
        case .notDetermined:
            print("📸 notDetermined → requesting access")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("📸 access result: \(granted)")
                DispatchQueue.main.async {
                    imagePickerSource = granted && UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
                    showImagePicker = true
                }
            }
        case .denied, .restricted:
            print("📸 denied/restricted → photo library")
            imagePickerSource = .photoLibrary
            showImagePicker = true
        @unknown default:
            imagePickerSource = .photoLibrary
            showImagePicker = true
        }
    }

    @ViewBuilder
    private func expandedQuestContent(quest: Quest) -> some View {
        let isCompleted = morphState.completedQuestTitles.contains(quest.title)

        VStack(spacing: 10) {
            // Photo banner — full-bleed at the top, matching the bar's 50pt
            // top corners. Drag handle sits as a white capsule overlay so the
            // photo visually goes all the way to the top edge.
            photoBanner(quest: quest, isCompleted: isCompleted)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 50,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 50,
                        style: .continuous
                    )
                )
                .contentShape(Rectangle())
                // Single drag gesture: drag down to dismiss, tap-near-top
                // also dismisses (the handle indicator is at the top edge).
                .gesture(
                    // No visual drag handle anymore — the photo itself is the
                    // gesture target. Generous, easy-to-trigger thresholds:
                    //   • drag > 25pt down → dismiss
                    //   • drag with downward velocity > 200pt/s → dismiss
                    //   • basically a tap (≤ 6pt total movement) → dismiss
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            let dx = abs(value.translation.width)
                            let dy = value.translation.height
                            let downwardVelocity = value.predictedEndTranslation.height - value.translation.height
                            if dy > 25 || downwardVelocity > 200 {
                                dismissExpanded()
                            } else if dx < 6 && abs(dy) < 6 {
                                dismissExpanded()
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )

            // Description — tinted glass card so the text reads cleanly
            // regardless of whatever map / hero photo is showing through
            // the bar's outer glass.
            Text(quest.description)
                .font(.subheadline)
                .foregroundColor(.black)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .adaptiveGlassEffectTinted(
                    color: Color.white.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .padding(.horizontal, 16)

            Spacer(minLength: 0)

            // Buttons row: View Quest + Navigate
            HStack(spacing: 8) {
                Button {
                    print("🎯 View Quest tapped — quest.id=\(quest.id ?? "nil"), title=\(quest.title)")
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    let q = quest
                    // Keep selectedQuest set so the pin stays highlighted and the map
                    // stays zoomed while the sheet is up. The expanded bar is hidden
                    // by the sheet anyway.
                    morphState.quest = q
                    onPresentQuestSheet(q)
                } label: {
                    Text("View Quest")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.cougarBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        // Light mode → subtle blue tint; dark mode → near-white.
                        .adaptiveGlassEffectTinted(
                            color: Color(UIColor { trait in
                                trait.userInterfaceStyle == .dark
                                    ? UIColor.white.withAlphaComponent(0.5)
                                    : (UIColor(named: "CougarBlue") ?? .systemBlue).withAlphaComponent(0.18)
                            }),
                            in: RoundedRectangle(cornerRadius: 22)
                        )
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
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func photoBanner(quest: Quest, isCompleted: Bool) -> some View {
        ZStack(alignment: .bottom) {
            // Photo / fallback gray
            if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
                    .clipped()
            } else {
                Color.gray.opacity(0.3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
            }

            // Gradient for legibility under the title/address
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(height: 130)
            .allowsHitTesting(false)

            // No visual drag handle — the photo IS the gesture target.
            // Title + address (left) and completion badge (right)
            HStack(alignment: .bottom, spacing: 8) {
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
                Spacer()
                if isCompleted {
                    completedBadge
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .allowsHitTesting(false)
        }
        .frame(height: 130)
    }

    @ViewBuilder
    private var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
            Text("Completed")
        }
        .font(.caption2)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.green.opacity(0.9))
        )
    }
}

struct ContentView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var morphState = MorphState.shared
    @ObservedObject private var deepLink = DeepLinkState.shared
    @State private var selectedTab: TabItem = .home
    @State private var isKeyboardVisible: Bool = false
    @State private var selectedQuest: Quest? = nil
    @State private var sheetQuest: Quest? = nil
    @State private var uploadError: String? = nil

    private func handleDeepLinkQuest(id: String) {
        print("🔗 handleDeepLinkQuest fetching id=\(id)")
        // Fetch the quest by id and open it on the QuestsView path so the
        // sheet UI we already have for this kicks in.
        Firestore.firestore().collection("quests").document(id).getDocument { snapshot, error in
            if let error = error {
                print("🔗 quest fetch error:", error.localizedDescription)
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("🔗 quest doc does not exist for id=\(id)")
                return
            }
            // Try Codable decode first (the @DocumentID path); fall back to
            // manual field extraction if that fails so a single missing
            // field doesn't kill the deep link.
            let quest: Quest
            if let decoded = try? snapshot.data(as: Quest.self) {
                quest = decoded
            } else if let data = snapshot.data() {
                print("🔗 Codable decode failed; falling back to manual field read")
                quest = Quest(
                    id: snapshot.documentID,
                    title: data["title"] as? String ?? "",
                    address: data["address"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    mapsLink: data["mapsLink"] as? String ?? "",
                    plusCode: data["plusCode"] as? String ?? "",
                    photoURL: data["photoURL"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    completedAt: (data["completedAt"] as? Timestamp)?.dateValue()
                )
            } else {
                print("🔗 quest data() returned nil")
                return
            }
            DispatchQueue.main.async {
                print("🔗 routing to quest sheet for \(quest.title)")
                selectedTab = .quests
                morphState.quest = quest
                sheetQuest = quest
                deepLink.pendingQuestId = nil
            }
        }
    }

    private let islandAnimation = Animation.spring(response: 0.65, dampingFraction: 0.65, blendDuration: 0.85)

    private func uploadPhoto(_ image: UIImage, for quest: Quest) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("‼️ upload aborted: no auth uid")
            uploadError = "You must be signed in to upload."
            return
        }
        // Path uses .jpg (matching the JPEG data we encode below).
        let storagePath = "\(uid)/\(quest.id ?? quest.title)/photo.jpg"
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("‼️ upload aborted: jpegData returned nil")
            uploadError = "Could not encode the image. Try again."
            return
        }
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        print("🚀 starting upload: path=\(storagePath), bytes=\(data.count), contentType=image/jpeg")
        morphState.isUploading = true
        Storage.storage().reference().child(storagePath).putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                let nsErr = error as NSError
                let detail = "[\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                print("‼️ upload failed:", detail)
                DispatchQueue.main.async {
                    morphState.isUploading = false
                    uploadError = "Upload failed.\n\(detail)\n\nIf this persists, check Firebase Storage rules allow writes to \(storagePath)."
                }
                return
            }
            print("🚀 upload succeeded, metadata=\(String(describing: metadata))")
            let userRef = Firestore.firestore().collection("users").document(uid)
            Firestore.firestore().runTransaction({ txn, _ in
                txn.updateData(
                    ["completedQuests": FieldValue.arrayUnion([quest.title])],
                    forDocument: userRef
                )
                let reward = Date().timeIntervalSince(quest.createdAt ?? Date()) <= 12*3600 ? 10 : 5
                txn.updateData(["points": FieldValue.increment(Int64(reward))], forDocument: userRef)
                return nil
            }) { _, _ in }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    morphState.isUploading = false
                    morphState.isComplete = true
                }
                let success = UINotificationFeedbackGenerator()
                success.notificationOccurred(.success)
                // Auto-dismiss after 2.5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        morphState.quest = nil
                        morphState.isComplete = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedQuest: $selectedQuest)
                .tag(TabItem.home)

            NavigationStack {
                QuestsView(selectedQuest: $selectedQuest)
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
            // Prefetch leaderboard once at app launch so the first Standings
            // tap doesn't kick off Firestore work mid-tab-transition.
            // Idempotent — repeat onAppear calls (e.g. after sheet dismiss)
            // do nothing.
            LeaderboardViewModel.shared.prefetchIfNeeded()
        }
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        let safeArea = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom }
            .first ?? 15

        FloatingTabBar(
            selectedTab: $selectedTab,
            selectedQuest: $selectedQuest,
            onImagePicked: { image in
                guard let quest = morphState.quest else { return }
                uploadPhoto(image, for: quest)
            },
            onPresentQuestSheet: { quest in
                print("🎯 ContentView received present, setting sheetQuest, current=\(String(describing: sheetQuest?.id))")
                sheetQuest = quest
            }
        )
        .padding(.bottom, safeArea * 0.3)
        .offset(y: 26)
        .animation(islandAnimation, value: morphState.quest?.id)
        .animation(islandAnimation, value: selectedTab == .quests && selectedQuest != nil)
    }

    var body: some View {
        mainContent
            .overlay(bottomOverlay, alignment: .bottom)
            .sheet(item: $sheetQuest, onDismiss: {
                // If user swipes the sheet down (rather than tapping X),
                // make sure morphState gets cleared too.
                if !morphState.isComplete {
                    morphState.quest = nil
                }
            }) { quest in
                QuestSheetView(quest: quest, parentUpload: { img in uploadPhoto(img, for: quest) })
            }
            .onChange(of: morphState.quest?.id) { newId in
                // Backup: if morphState.quest is cleared (e.g. by upload completion
                // auto-dismiss), make sure sheetQuest follows.
                print("🎯 onChange morphState.quest?.id = \(newId ?? "nil")")
                if newId == nil, sheetQuest != nil {
                    sheetQuest = nil
                }
            }
            .onChange(of: sheetQuest?.id) { newId in
                print("🎯 onChange sheetQuest?.id = \(newId ?? "nil")")
            }
            .onChange(of: selectedTab) { newTab in
                if newTab != .quests {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        selectedQuest = nil
                    }
                }
                // Switching tabs ALWAYS clears any in-flight quest morph state,
                // so a stale morphState.quest from a failed sheet attempt can't
                // bleed onto HomeView's morph bar.
                if morphState.quest != nil { morphState.quest = nil }
                if sheetQuest != nil { sheetQuest = nil }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .onChange(of: selectedQuest != nil) { hasQuest in
                if hasQuest {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred()
                }
            }
            .alert("Upload Failed", isPresented: Binding(
                get: { uploadError != nil },
                set: { newValue in if !newValue { uploadError = nil } }
            ), presenting: uploadError) { _ in
                Button("OK", role: .cancel) { uploadError = nil }
            } message: { msg in
                Text(msg)
            }
            // .onReceive on the publisher directly is more reliable than
            // .onChange when the @Published is set during a callback chain
            // (.onOpenURL, .onContinueUserActivity).
            .onReceive(deepLink.$pendingQuestId.compactMap { $0 }) { id in
                print("🔗 ContentView received pendingQuestId=\(id)")
                handleDeepLinkQuest(id: id)
            }
    }
}

// MARK: - Quest Sheet (presented from QuestsView path)

struct QuestSheetView: View {
    let quest: Quest
    let parentUpload: (UIImage) -> Void
    @ObservedObject private var morphState = MorphState.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var pickedImage: UIImage?

    private var sheetSafeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom }
            .first ?? 15
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // NavigationStack wrap so QuestView's `.toolbar` (Share button)
            // surfaces in the sheet path too. Background hidden so the
            // QuestView's hero photo bleeds up under the nav bar.
            NavigationStack {
                QuestView(
                    quest: quest,
                    isQuestOpen: Binding(
                        get: { morphState.quest != nil },
                        set: { newValue in
                            if !newValue {
                                morphState.quest = nil
                                dismiss()
                            }
                        }
                    )
                )
                .ignoresSafeArea()
            }

            MorphActionBar(
                onDismiss: {
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                    morphState.quest = nil
                    dismiss()
                },
                onPhotoLibrary: {
                    print("📷 [sheet] Photo library tapped")
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                },
                onCapture: {
                    print("📸 [sheet] Capture tapped")
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                    requestCameraThenPresent()
                }
            )
            // Match the main FloatingTabBar's vertical position EXACTLY.
            // The trick is that the sheet's content respects safe area while
            // the main bar's host (mainContent.overlay(...)) extends through
            // it. We compensate by having the ZStack ignore the bottom safe
            // area below — then the same padding+offset math lands at the
            // same screen coordinates.
            .padding(.horizontal, 20)
            .padding(.bottom, sheetSafeAreaBottom * 0.3)
            .offset(y: 26)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                source: imagePickerSource == .camera ? .camera : .library,
                image: $pickedImage
            )
        }
        .onChange(of: pickedImage) { image in
            guard let img = image else { return }
            parentUpload(img)
            pickedImage = nil
            // Keep the sheet up so the morph bar can show "Uploading…" / "Quest Complete!"
            // The parentUpload will set morphState.quest = nil on completion, dismissing.
        }
    }

    private func requestCameraThenPresent() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📸 [sheet] camera auth status: \(status.rawValue)")
        switch status {
        case .authorized:
            imagePickerSource = .camera
            showImagePicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    imagePickerSource = granted && UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
                    showImagePicker = true
                }
            }
        case .denied, .restricted:
            imagePickerSource = .photoLibrary
            showImagePicker = true
        @unknown default:
            imagePickerSource = .photoLibrary
            showImagePicker = true
        }
    }
}

// MARK: - Reusable Morph Action Bar (X / photo / capture / uploading / complete)

struct MorphActionBar: View {
    let onDismiss: () -> Void
    let onPhotoLibrary: () -> Void
    let onCapture: () -> Void
    @ObservedObject private var morphState = MorphState.shared

    var body: some View {
        ZStack {
            Color.clear
                .frame(height: 68)
                .adaptiveGlassEffect(in: RoundedRectangle(cornerRadius: 50))
                .allowsHitTesting(false)

            Group {
                if morphState.isComplete || morphState.isQuestAlreadyCompleted {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Quest Complete!")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .adaptiveGlassEffectTinted(color: .cougarBlue, in: RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }
                } else if morphState.isUploading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("Uploading…")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .adaptiveGlassEffectTinted(color: .cougarBlue, in: RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 6)
                } else {
                    HStack(spacing: 8) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onPhotoLibrary) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onCapture) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                Text("Capture")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .adaptiveGlassEffectTinted(color: .cougarBlue, in: RoundedRectangle(cornerRadius: 28))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 68)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: morphState.isUploading)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: morphState.isComplete)
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
