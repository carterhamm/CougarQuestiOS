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
import MapKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Kingfisher

/// Routes incoming Universal Links / App Clip URLs into the running app.
/// `CougarQuestApp.swift`'s `.onOpenURL` writes here; `ContentView` observes
/// `pendingQuestId` and opens the matching quest.
final class DeepLinkState: ObservableObject {
    static let shared = DeepLinkState()
    /// Set by ContentView after fetching the quest by id.
    /// HomeView observes this and pushes onto its NavigationStack so the
    /// deep-linked quest opens as a full QuestView (not a sheet overlay).
    @Published var pushOnHomeQuestId: String? = nil
    /// Internal: id parsed from the URL but not yet handled by ContentView.
    @Published var pendingQuestId: String? = nil
    private init() {}

    func handle(_ url: URL) {
        guard let id = CougarQuestLink.questId(from: url) else { return }
        // Defer to the next runloop. Setting an @Published synchronously
        // inside .onOpenURL / .onContinueUserActivity sometimes loses the
        // change to SwiftUI's diff (it's still mid-update for the URL
        // delivery). A trailing dispatch makes the observation reliable.
        DispatchQueue.main.async { [weak self] in
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

private enum PendingImagePicker: String, Identifiable {
    case library, camera
    var id: String { rawValue }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: TabItem
    @Binding var selectedQuest: Quest?
    let onImagePicked: (UIImage) -> Void
    let onPresentQuestSheet: (Quest) -> Void
    @ObservedObject var morphState = MorphState.shared
    @Namespace private var animation
    @State private var dragOffset: CGFloat = 0
    @State private var pendingPicker: PendingImagePicker? = nil
    @State private var pickedImage: UIImage?
    @State private var showCameraSettingsAlert = false
    @State private var tabDragX: CGFloat = 0
    @State private var isDraggingTabPill: Bool = false
    @State private var tabDragVelocity: CGFloat = 0  // pts/s
    @State private var lastDragSampleX: CGFloat = 0
    @State private var lastDragSampleTime: Date = .init()

    private var isMorphActive: Bool {
        // Main floating bar only morphs on the HomeView path.
        // QuestsView path uses a sheet with its own MorphActionBar.
        selectedTab == .home && (morphState.quest != nil || morphState.isComplete)
    }

    /// Fixed layout regions inside the expanded bar (everything except the
    /// description card). Used to compute the bar's total height so the
    /// description can grow without overlapping View Quest / Navigate.
    private static let expandedBarFixedHeight: CGFloat = {
        // photoBanner(170) + topSpacing(10) + descriptionCardPaddingV(20)
        // + bottomSpacing(10) + buttonsRow(44) + bottomPad(4)
        // + reservedForTabRow(80) + photoOffset(80)
        let photo: CGFloat = 170
        let descPaddingV: CGFloat = 20
        let buttons: CGFloat = 44
        let stackSpacings: CGFloat = 10 * 2
        let bottomChrome: CGFloat = 84  // bottomPad + reserved tab row + offset adjustment
        return photo + descPaddingV + buttons + stackSpacings + bottomChrome
    }()

    /// Compute the actual rendered height of the description text at
    /// subheadline font, capped at 5 lines so the bar can't grow forever.
    private func descriptionHeight(for quest: Quest) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        // Outer FloatingTabBar padding (20*2) + description card horizontal
        // padding (16*2) + inner card text padding (12*2)
        let textWidth = max(120, screenWidth - 96)
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let bounds = (quest.description as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        // Cap at ~5 lines worth of text (matches .lineLimit(5) on the Text).
        let maxHeight = font.lineHeight * 5 + 4
        return min(ceil(bounds.height), maxHeight)
    }

    private var capsuleHeight: CGFloat {
        guard selectedTab == .quests, let quest = selectedQuest else { return 68 }
        // Bar height = fixed chrome + actual description text height.
        // Means the bar grows naturally with multi-line descriptions
        // instead of pushing the buttons out of frame.
        return Self.expandedBarFixedHeight + descriptionHeight(for: quest)
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
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
        .fullScreenCover(item: $pendingPicker) { src in
            ImagePicker(
                source: src == .camera ? .camera : .library,
                image: $pickedImage
            )
            .ignoresSafeArea()
        }
        .onChange(of: pickedImage) { image in
            guard let img = image else { return }
            onImagePicked(img)
            pickedImage = nil
        }
        .alert("Camera Access Needed", isPresented: $showCameraSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To take a photo for your quest, allow camera access in Settings.")
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        GeometryReader { geo in
            let tabs = TabItem.allCases
            let cellWidth = (geo.size.width - 12) / CGFloat(tabs.count)
            let currentIdx = tabs.firstIndex(of: selectedTab) ?? 0
            let baseX = 6 + cellWidth * CGFloat(currentIdx)
            let minDragX: CGFloat = -baseX
            let maxDragX: CGFloat = (geo.size.width - 6) - (baseX + cellWidth)

            // Drag pill: separate X/Y lift so we can tune width and height
            // independently. ~8% less max width and ~10% more max height
            // than the previous symmetric 1.45 lift.
            let pillBaseHeight: CGFloat = 56
            let liftScaleX: CGFloat = isDraggingTabPill ? 1.34 : 1.0
            let liftScaleY: CGFloat = isDraggingTabPill ? 1.6 : 1.0
            let velocityNorm = max(-1, min(1, tabDragVelocity / 700))
            let speedAbs = abs(velocityNorm)
            let stretchX: CGFloat = isDraggingTabPill ? (1 + speedAbs * 0.4) : 1.0
            let squashY: CGFloat = isDraggingTabPill ? (1 - speedAbs * 0.4) : 1.0

            ZStack(alignment: .leading) {
                // Active pill — sits BELOW the icons at rest (so the white
                // active-tab icon shows on top of the blue glass), pops ABOVE
                // the icons while dragging (so its magnified silhouette isn't
                // clipped by labels).
                ZStack {
                    Color.clear
                        .frame(width: cellWidth, height: pillBaseHeight)
                        .adaptiveGlassEffectTinted(color: Color.cougarBlue.opacity(0.9), in: RoundedRectangle(cornerRadius: 50))
                        .opacity(isDraggingTabPill ? 0 : 1)
                    // Drag-mode pill: Liquid Glass on the rim, flush to the
                    // outer edge. A crisp 3pt outer line guarantees full
                    // alpha at the very edge (otherwise blur halves it),
                    // with a wider blurred band beneath fading invisibly
                    // inward — no visible gradient stripe.
                    Color.clear
                        .frame(width: cellWidth, height: pillBaseHeight)
                        .adaptiveGlassEffect(in: RoundedRectangle(cornerRadius: 50))
                        .mask(
                            ZStack {
                                RoundedRectangle(cornerRadius: 50, style: .continuous)
                                    .strokeBorder(Color.white, lineWidth: 11)
                                    .blur(radius: 7)
                                RoundedRectangle(cornerRadius: 50, style: .continuous)
                                    .strokeBorder(Color.white, lineWidth: 2)
                            }
                        )
                        .opacity(isDraggingTabPill ? 1 : 0)
                }
                .shadow(color: Color.cougarBlue.opacity(isDraggingTabPill ? 0.55 : 0.25), radius: isDraggingTabPill ? 32 : 15, x: 0, y: isDraggingTabPill ? 12 : 5)
                .scaleEffect(x: liftScaleX * stretchX, y: liftScaleY * squashY, anchor: .center)
                .offset(x: baseX + tabDragX)
                .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.65), value: tabDragX)
                .animation(.spring(response: 0.55, dampingFraction: 0.42), value: selectedTab)
                .animation(.spring(response: 0.4, dampingFraction: 0.4), value: isDraggingTabPill)
                .animation(.spring(response: 0.3, dampingFraction: 0.42), value: tabDragVelocity)
                .zIndex(isDraggingTabPill ? 2 : 0)

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
                    }
                }
                .padding(.horizontal, 6)
                .zIndex(1)
            }
            .contentShape(Rectangle())
            // High-priority drag so it wins over child taps and activates
            // on the first touch (minimumDistance: 0 = instant).
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let now = Date()
                        if !isDraggingTabPill {
                            isDraggingTabPill = true
                            lastDragSampleX = value.location.x
                            lastDragSampleTime = now
                            let g = UIImpactFeedbackGenerator(style: .soft)
                            g.impactOccurred()
                        } else {
                            let dt = now.timeIntervalSince(lastDragSampleTime)
                            if dt > 0.001 {
                                let dx = value.location.x - lastDragSampleX
                                // 60/40 EMA — responsive to speed changes
                                // without going twitchy. Pairs with the
                                // looser spring below for expressive jiggle.
                                let raw = dx / CGFloat(dt)
                                tabDragVelocity = tabDragVelocity * 0.6 + raw * 0.4
                                lastDragSampleX = value.location.x
                                lastDragSampleTime = now
                            }
                        }
                        let pillCenter = baseX + cellWidth / 2
                        let raw = value.location.x - pillCenter
                        tabDragX = max(minDragX, min(maxDragX, raw))
                    }
                    .onEnded { value in
                        let totalTravel = abs(value.translation.width)
                        let isTap = totalTravel < 6
                        // Snap to the cell the PILL is currently centered on.
                        // Using value.location.x or predictedEndLocation gave
                        // off-by-one snaps because the pill center isn't the
                        // finger location — they're offset.
                        let pillCenter: CGFloat = isTap
                            ? value.location.x
                            : (baseX + cellWidth / 2 + tabDragX)
                        let rawIdx = (pillCenter - 6 - cellWidth / 2) / cellWidth
                        let snapIdx = max(0, min(tabs.count - 1, Int(rawIdx.rounded())))
                        let target = tabs[snapIdx]

                        let g = UIImpactFeedbackGenerator(style: .heavy)
                        g.impactOccurred()
                        // Loose release spring — overshoots, wobbles, settles.
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                            selectedTab = target
                            tabDragX = 0
                            isDraggingTabPill = false
                            tabDragVelocity = 0
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
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                pendingPicker = .library
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
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
        switch status {
        case .authorized:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                showCameraSettingsAlert = true
                return
            }
            pendingPicker = .camera
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted && UIImagePickerController.isSourceTypeAvailable(.camera) {
                        pendingPicker = .camera
                    } else {
                        showCameraSettingsAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraSettingsAlert = true
        @unknown default:
            showCameraSettingsAlert = true
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
                .foregroundColor(Color(UIColor { trait in
                    trait.userInterfaceStyle == .dark ? .white : .black
                }))
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .adaptiveGlassEffectTinted(
                    color: Color(UIColor { trait in
                        trait.userInterfaceStyle == .dark
                            ? UIColor.black.withAlphaComponent(0.45)
                            : UIColor.white.withAlphaComponent(0.65)
                    }),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .padding(.horizontal, 16)

            Spacer(minLength: 0)

            // Buttons row: View Quest + Navigate
            HStack(spacing: 8) {
                Button {
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
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        // Light mode: near-white glass tint (lighter than
                        // before). Dark mode: white-ish glass.
                        .adaptiveGlassEffectTinted(
                            color: Color(UIColor { trait in
                                trait.userInterfaceStyle == .dark
                                    ? UIColor.white.withAlphaComponent(0.5)
                                    : UIColor.white.withAlphaComponent(0.7)
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
        let bannerHeight: CGFloat = 170
        ZStack(alignment: .bottom) {
            // Photo / fallback gray. Clean photo — overlaying glassEffect
            // on a moving image creates cached/frozen distortion artifacts.
            if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: bannerHeight)
                    .clipped()
            } else {
                Color.gray.opacity(0.3)
                    .frame(maxWidth: .infinity)
                    .frame(height: bannerHeight)
            }

            // Vignette: darkens top + left + right edges, leaves bottom
            // clear (the bottom already has its own gradient for title legibility).
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.45)
                )
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.black.opacity(0.30), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 70)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.30)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 70)
                }
            }
            .frame(height: bannerHeight)
            .allowsHitTesting(false)

            // Bottom gradient for title/address legibility
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(height: bannerHeight)
            .allowsHitTesting(false)

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
        .frame(height: bannerHeight)
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
        .adaptiveGlassEffectTinted(color: Color.cougarBlue.opacity(0.7), in: Capsule())
    }
}

struct ContentView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var morphState = MorphState.shared
    @ObservedObject private var deepLink = DeepLinkState.shared
    @State private var selectedTab: TabItem = .home
    @ObservedObject private var keyboard = KeyboardMonitor.shared
    @State private var selectedQuest: Quest? = nil
    @State private var sheetQuest: Quest? = nil
    @State private var uploadError: String? = nil

    private func handleDeepLinkQuest(id: String) {
        // Fetch the quest by id and open it on the QuestsView path so the
        // sheet UI we already have for this kicks in.
        Firestore.firestore().collection("quests").document(id).getDocument { snapshot, error in
            if error != nil { return }
            guard let snapshot = snapshot, snapshot.exists else { return }
            // Try Codable decode first (the @DocumentID path); fall back to
            // manual field extraction if that fails so a single missing
            // field doesn't kill the deep link.
            let quest: Quest
            if let decoded = try? snapshot.data(as: Quest.self) {
                quest = decoded
            } else if let data = snapshot.data() {
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
                return
            }
            DispatchQueue.main.async {
                // Open in full QuestView via HomeView's NavigationStack
                // (not the sheet on QuestsView) — deep links from outside
                // the app should land on the immersive view, not a card.
                selectedTab = .home
                morphState.quest = quest
                deepLink.pushOnHomeQuestId = id
                deepLink.pendingQuestId = nil
            }
        }
    }

    private let islandAnimation = Animation.spring(response: 0.65, dampingFraction: 0.65, blendDuration: 0.85)

    private func uploadPhoto(_ image: UIImage, for quest: Quest) {
        guard let uid = Auth.auth().currentUser?.uid else {
            uploadError = "You must be signed in to upload."
            return
        }
        // Path uses .jpg (matching the JPEG data we encode below).
        let storagePath = "\(uid)/\(quest.id ?? quest.title)/photo.jpg"
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            uploadError = "Could not encode the image. Try again."
            return
        }
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        morphState.isUploading = true
        Storage.storage().reference().child(storagePath).putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                let nsErr = error as NSError
                let detail = "[\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                DispatchQueue.main.async {
                    morphState.isUploading = false
                    uploadError = "Upload failed.\n\(detail)\n\nIf this persists, check Firebase Storage rules allow writes to \(storagePath)."
                }
                return
            }
            let userRef = Firestore.firestore().collection("users").document(uid)
            Firestore.firestore().runTransaction({ txn, _ in
                txn.updateData(
                    ["completedQuests": FieldValue.arrayUnion([quest.title])],
                    forDocument: userRef
                )
                let reward = Date().timeIntervalSince(quest.createdAt ?? Date()) <= 12*3600 ? 10 : 5
                txn.updateData([
                    "points": FieldValue.increment(Int64(reward)),
                    "currentSeasonPoints": FieldValue.increment(Int64(reward))
                ], forDocument: userRef)
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

    /// TabView with the .page style — has no tab bar at all (page-style
    /// renders a horizontal pager). Tab selection is driven entirely by the
    /// custom FloatingTabBar via `selection: $selectedTab`. iOS 26's
    /// floating system tab bar is only rendered for the default tab style,
    /// not for .page, so this definitively suppresses it. Per-tab state
    /// is preserved (HomeView's path, QuestsView's region, etc.).
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
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
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
                sheetQuest = quest
            }
        )
        .padding(.bottom, safeArea * 0.3)
        .offset(y: 26)
        .animation(islandAnimation, value: morphState.quest?.id)
        .animation(islandAnimation, value: selectedTab == .quests && selectedQuest != nil)
    }

    /// Coordinate region the QuestsView Map will eventually use. Pre-rendering
    /// it via a 1×1pt invisible Map at app launch warms MapKit's tile cache so
    /// the first navigation to QuestsView doesn't flash + load tiles in mid-view.
    private var mapPrewarmRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.2529, longitude: -111.6498),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    var body: some View {
        mainContent
            .background(
                // Invisible Map that triggers MapKit tile loading at launch.
                Map(coordinateRegion: .constant(mapPrewarmRegion))
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .bottom) {
                if !keyboard.isVisible {
                    bottomOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: keyboard.isVisible)
            .fullScreenCover(item: $sheetQuest, onDismiss: {
                if !morphState.isComplete {
                    morphState.quest = nil
                }
            }) { quest in
                QuestSheetView(quest: quest, parentUpload: { img in uploadPhoto(img, for: quest) })
            }
            .onChange(of: morphState.quest?.id) { newId in
                // Backup: if morphState.quest is cleared (e.g. by upload completion
                // auto-dismiss), make sure sheetQuest follows.
                if newId == nil, sheetQuest != nil {
                    sheetQuest = nil
                }
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

    @State private var pendingPicker: PendingImagePicker? = nil
    @State private var pickedImage: UIImage?
    @State private var showCameraSettingsAlert = false

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
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                    pendingPicker = .library
                },
                onCapture: {
                    let g = UIImpactFeedbackGenerator(style: .heavy)
                    g.impactOccurred()
                    requestCameraThenPresent()
                }
            )
            // Position relative to the sheet's safe area (matches what the
            // user perceives as "where the tab bar usually is"). Earlier
            // attempts ignored the safe area and applied the main bar's
            // .offset(y: 26), which pushed the bar 16pt off-screen below
            // the home indicator.
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .fullScreenCover(item: $pendingPicker) { src in
            ImagePicker(
                source: src == .camera ? .camera : .library,
                image: $pickedImage
            )
            .ignoresSafeArea()
        }
        .onChange(of: pickedImage) { image in
            guard let img = image else { return }
            parentUpload(img)
            pickedImage = nil
            // Keep the sheet up so the morph bar can show "Uploading…" / "Quest Complete!"
            // The parentUpload will set morphState.quest = nil on completion, dismissing.
        }
        .alert("Camera Access Needed", isPresented: $showCameraSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To take a photo for your quest, allow camera access in Settings.")
        }
    }

    private func requestCameraThenPresent() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                showCameraSettingsAlert = true
                return
            }
            pendingPicker = .camera
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted && UIImagePickerController.isSourceTypeAvailable(.camera) {
                        pendingPicker = .camera
                    } else {
                        showCameraSettingsAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraSettingsAlert = true
        @unknown default:
            showCameraSettingsAlert = true
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
