//
//  HomeView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/23/25.
//

import SwiftUI
import Foundation
import UIKit
import Combine
import Kingfisher
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @Binding var selectedQuest: Quest?
    @ObservedObject private var morphState = MorphState.shared
    @State private var path: [String] = []
    @State private var quests: [Quest] = []
    @State private var completedQuestTitles: [String] = []
    @State private var isLoading: Bool = true
    @EnvironmentObject var profileVM: ProfileViewModel
    @Namespace private var namespace
    @State private var greeting: String = ""

    private var visibleQuests: [Quest] {
        quests.filter {
            !($0.title.isEmpty &&
              $0.photoURL.isEmpty &&
              $0.address.isEmpty &&
              $0.mapsLink.isEmpty &&
              $0.description.isEmpty)
        }
    }

    private var forYouQuests: [Quest] {
        visibleQuests.filter { !completedQuestTitles.contains($0.title) }
    }

    private var completedQuestsList: [Quest] {
        visibleQuests.filter { completedQuestTitles.contains($0.title) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            scrollContent
                .ignoresSafeArea(edges: .top)
                .navigationDestination(for: String.self) { id in
                    // Resolve the quest from the local list first; fall back to
                    // morphState.quest so deep-linked quests (which may not be in
                    // `quests` yet) still render.
                    let resolved = quests.first(where: { $0.id == id })
                        ?? (morphState.quest?.id == id ? morphState.quest : nil)
                    if let quest = resolved {
                        if #available(iOS 18, *) {
                            QuestView(quest: quest, isQuestOpen: .constant(true))
                                .navigationTransition(.zoom(sourceID: id, in: namespace))
                        } else {
                            QuestView(quest: quest, isQuestOpen: .constant(true))
                        }
                    }
                }
        }
        .onChange(of: path) { newPath in
            if newPath.isEmpty && morphState.quest != nil {
                morphState.quest = nil
            }
        }
        .onChange(of: morphState.quest?.id) { newId in
            if newId == nil && !path.isEmpty {
                path.removeAll()
            }
        }
        // Universal-link hand-off: ContentView fetches the quest by id and
        // signals here. We push onto the NavigationStack so the user lands
        // in full QuestView, not the QuestsView sheet.
        .onReceive(DeepLinkState.shared.$pushOnHomeQuestId.compactMap { $0 }) { id in
            print("🔗 HomeView pushing deep-linked quest id=\(id)")
            if !path.contains(id) {
                path.append(id)
            }
            DeepLinkState.shared.pushOnHomeQuestId = nil
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        ScrollViewReader { scrollProxy in
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: Hero Section
                    VStack(spacing: 0) {
                        // Mirror of the top 12% of the hero image (48pt).
                        // Image and gradient are siblings in a ZStack so the
                        // gradient isn't flipped along with the image
                        // (.scaleEffect on the image was flipping its
                        // .overlay too, hiding the dark scrim).
                        ZStack {
                            Image("MarriottCenterHome")
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width, height: 400)
                                .clipped()
                                .frame(width: UIScreen.main.bounds.width, height: 48, alignment: .top)
                                .clipped()
                                .scaleEffect(y: -1)

                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.black.opacity(0.85), location: 0.0),
                                    .init(color: Color.black.opacity(0.0),  location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .frame(width: UIScreen.main.bounds.width, height: 48)
                        .clipped()

                        ZStack(alignment: .bottomLeading) {
                            Image("MarriottCenterHome")
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width, height: 400)
                                .clipped()
                                // Same soft fade overlay as QuestView's header —
                                // duplicate of the image masked with a bottom-up
                                // gradient. No colorMultiply (that darkened the
                                // whole image earlier).
                                .overlay(
                                    Image("MarriottCenterHome")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width, height: 400)
                                        .clipped()
                                        .mask(
                                            LinearGradient(
                                                gradient: Gradient(stops: [
                                                    .init(color: Color.white.opacity(0.45), location: 1.0),
                                                    .init(color: Color.white.opacity(0),    location: 0.6)
                                                ]),
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                )
                            // Dark gradient at the bottom (separate from the
                            // image-overlay) so the title/greeting sit on a
                            // visibly dark base. Only applies to the bottom
                            // ~50% of the hero.
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.75),
                                    Color.clear
                                ]),
                                startPoint: .bottom,
                                endPoint: .center
                            )
                            VStack(alignment: .leading, spacing: 8) {
                            Text("BYU Fathers and Sons")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            if greeting.isEmpty {
                                // Wider placeholder so the skeleton isn't a
                                // sliver — visible width while we wait for
                                // the real greeting to arrive.
                                Text("Welcome back")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .redacted(reason: .placeholder)
                            } else {
                                Text(greeting)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.bottom, 16)
                        }
                        .frame(height: 400)
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // MARK: Team Progress Card
                    if isLoading {
                        // Skeleton version — shows the card shape while
                        // we wait for the quest counts to load.
                        TeamProgressCard(
                            profileVM: profileVM,
                            completedCount: 0,
                            totalCount: 0
                        )
                        .padding(.horizontal)
                        .redacted(reason: .placeholder)
                    } else if !visibleQuests.isEmpty {
                        Button {
                            // Quick scroll — feels responsive (was 0.5s, sluggish).
                            withAnimation(.easeOut(duration: 0.25)) {
                                scrollProxy.scrollTo("completed-section", anchor: .top)
                            }
                            let g = UIImpactFeedbackGenerator(style: .light)
                            g.impactOccurred()
                        } label: {
                            TeamProgressCard(
                                profileVM: profileVM,
                                completedCount: completedQuestTitles.count,
                                totalCount: visibleQuests.count
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    // MARK: For You Section
                    if isLoading {
                        // Skeleton loader for "For You"
                        Text("For You")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .redacted(reason: .placeholder)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Color.gray.opacity(0.3)
                                        .frame(width: 150, height: 150)
                                        .cornerRadius(20)
                                        .redacted(reason: .placeholder)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        ForYouSectionView(
                            quests: forYouQuests,
                            namespace: namespace,
                            path: $path
                        )
                        .environmentObject(profileVM)
                    }
                    
                    // MARK: Completed Quests Section
                    Group {
                        if isLoading {
                            Text("Completed Quests")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .redacted(reason: .placeholder)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Color.gray.opacity(0.3)
                                            .frame(width: 150, height: 150)
                                            .cornerRadius(20)
                                            .redacted(reason: .placeholder)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else {
                            CompletedSectionView(
                                quests: completedQuestsList,
                                namespace: namespace,
                                path: $path
                            )
                            .environmentObject(profileVM)
                        }
                    }
                    .id("completed-section")
                    
                    if !isLoading && forYouQuests.isEmpty && completedQuestsList.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "xmark")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No quests currently available, please check back later")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                    }
                    
                    // Extra vertical spacing for scrolling.
                    // Half-height when the Completed Quests section is visible
                    // — that section already adds significant vertical content,
                    // so the original 300pt of trailing space ends up feeling
                    // empty / over-scrolled.
                    Color.clear
                        .frame(height: completedQuestsList.isEmpty ? 300 : 150)
                }
            }
            .ignoresSafeArea(edges: .top)
        .onAppear {
            FirebaseService.shared.fetchQuests { fetched, error in
                if let fetched = fetched {
                    self.quests = fetched
                }
                self.isLoading = false
            }
            if let uid = Auth.auth().currentUser?.uid {
                Firestore.firestore().collection("users").document(uid)
                    .addSnapshotListener { snapshot, _ in
                        let array = snapshot?.data()?["completedQuests"] as? [String] ?? []
                        // Always update the shared MorphState immediately so the
                        // morph bar can show "Quest Complete!" when re-opening
                        // a finished quest. The local re-filter below is what
                        // gets deferred (to avoid mid-zoom tile reshuffles).
                        morphState.completedQuestTitles = Set(array)
                        // Defer the section re-filter so the .zoom back-transition
                        // can complete before the source tile moves from For You → Completed.
                        let isInQuest = !path.isEmpty
                        let updateBlock = {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                completedQuestTitles = array
                            }
                        }
                        if isInQuest {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: updateBlock)
                        } else {
                            updateBlock()
                        }
                    }
                // Fetch user name for greeting
                let userRef = Firestore.firestore().collection("users").document(uid)
                userRef.getDocument { snapshot, _ in
                    let weekday = DateFormatter().weekdaySymbols[
                        Calendar.current.component(.weekday, from: Date()) - 1
                    ]
                    // Remove personalized name; use general greetings
                    let hour = Calendar.current.component(.hour, from: Date())
                    let timeOfDayGreeting: String
                    switch hour {
                    case 5..<12: timeOfDayGreeting = "Good morning!"
                    case 12..<17: timeOfDayGreeting = "Good afternoon!"
                    case 17..<22: timeOfDayGreeting = "Good evening!"
                    default: timeOfDayGreeting = "Hello!"
                    }
                    let weekdayGreeting = "Happy \(weekday)!"
                    let options = [
                        "Welcome!",
                        weekdayGreeting,
                        timeOfDayGreeting
                    ]
                    DispatchQueue.main.async {
                        greeting = options.randomElement()!
                    }
                }
            }
        }
        } // ScrollViewReader
    }

}

struct ForYouSectionView: View {
    let quests: [Quest]
    let namespace: Namespace.ID
    @Binding var path: [String]
    @ObservedObject var morphState = MorphState.shared
    @EnvironmentObject var profileVM: ProfileViewModel

    var body: some View {
        if !quests.isEmpty {
            Text("For You")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(quests) { quest in
                        if #available(iOS 18, *) {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .rigid)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    morphState.quest = quest
                                }
                                if let id = quest.id { path.append(id) }
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                                        KFImage(url)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipped()
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 150, height: 150)
                                    }
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                                        startPoint: .bottom,
                                        endPoint: .center
                                    )
                                    .frame(width: 150, height: 150)
                                    Text(quest.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(12)
                                }
                                .frame(width: 150, height: 150)
                                .cornerRadius(20)
                            }
                            .matchedTransitionSource(id: quest.id ?? "", in: namespace)
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    if let url = URL(string: quest.mapsLink),
                                       UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Navigate", systemImage: "arrow.right")
                                }
                                if profileVM.isAdmin {
                                    Button(role: .destructive) {
                                        FirebaseService.shared.deleteQuest(quest) { _ in }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } else {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .rigid)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    morphState.quest = quest
                                }
                                if let id = quest.id { path.append(id) }
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                                        KFImage(url)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipped()
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 150, height: 150)
                                    }
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                                        startPoint: .bottom,
                                        endPoint: .center
                                    )
                                    .frame(width: 150, height: 150)
                                    Text(quest.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(12)
                                }
                                .frame(width: 150, height: 150)
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    if let url = URL(string: quest.mapsLink),
                                       UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Navigate", systemImage: "arrow.right")
                                }
                                if profileVM.isAdmin {
                                    Button(role: .destructive) {
                                        FirebaseService.shared.deleteQuest(quest) { _ in }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct CompletedSectionView: View {
    let quests: [Quest]
    let namespace: Namespace.ID
    @Binding var path: [String]
    @ObservedObject var morphState = MorphState.shared
    @EnvironmentObject var profileVM: ProfileViewModel

    var body: some View {
        if !quests.isEmpty {
            Text("Completed Quests")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(quests) { quest in
                        if #available(iOS 18, *) {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .rigid)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    morphState.quest = quest
                                }
                                if let id = quest.id { path.append(id) }
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                                        KFImage(url)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipped()
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 150, height: 150)
                                    }
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                                        startPoint: .bottom,
                                        endPoint: .center
                                    )
                                    .frame(width: 150, height: 150)
                                    Text(quest.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(12)
                                }
                                .frame(width: 150, height: 150)
                                .cornerRadius(20)
                            }
                            .matchedTransitionSource(id: quest.id ?? "", in: namespace)
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    if let url = URL(string: quest.mapsLink),
                                       UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Navigate", systemImage: "arrow.right")
                                }
                                if profileVM.isAdmin {
                                    Button(role: .destructive) {
                                        FirebaseService.shared.deleteQuest(quest) { _ in }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } else {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .rigid)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    morphState.quest = quest
                                }
                                if let id = quest.id { path.append(id) }
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                                        KFImage(url)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipped()
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 150, height: 150)
                                    }
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                                        startPoint: .bottom,
                                        endPoint: .center
                                    )
                                    .frame(width: 150, height: 150)
                                    Text(quest.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(12)
                                }
                                .frame(width: 150, height: 150)
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    if let url = URL(string: quest.mapsLink),
                                       UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Navigate", systemImage: "arrow.right")
                                }
                                if profileVM.isAdmin {
                                    Button(role: .destructive) {
                                        FirebaseService.shared.deleteQuest(quest) { _ in }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Team Progress Card

struct TeamProgressCard: View {
    let profileVM: ProfileViewModel
    let completedCount: Int
    let totalCount: Int

    private var teamName: String {
        if !profileVM.teamName.isEmpty { return profileVM.teamName }
        let parts = [profileVM.firstName, profileVM.lastName].filter { !$0.isEmpty }
        let dad = parts.joined(separator: " ")
        return dad.isEmpty ? "Your Team" : "\(dad) Family"
    }

    private var members: [String] {
        var list: [String] = []
        if !profileVM.grandpa.isEmpty { list.append(profileVM.grandpa) }
        list.append(contentsOf: profileVM.sons.filter { !$0.isEmpty })
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(teamName)
                            .font(.headline)
                            .fontWeight(.bold)
                        if !members.isEmpty {
                            Text(members.joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(completedCount)")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.cougarBlue)
                        Text("/ \(totalCount)")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    Text("quests done")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cougarBlue.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cougarBlue)
                        .frame(
                            width: totalCount > 0
                                ? geo.size.width * CGFloat(completedCount) / CGFloat(totalCount)
                                : 0,
                            height: 8
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completedCount)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .adaptiveGlassEffect(
            in: RoundedRectangle(cornerRadius: 20),
            strokeColor: Color.gray.opacity(0.2),
            strokeWidth: 1
        )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(selectedQuest: .constant(nil))
            .environmentObject(ProfileViewModel())
    }
}
