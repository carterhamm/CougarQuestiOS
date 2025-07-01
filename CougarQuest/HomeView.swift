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
    @Binding var isQuestOpen: Bool
    @Binding var selectedQuest: Quest? // Added binding
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
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: Hero Section
                    ZStack(alignment: .bottomLeading) {
                        Image("MarriottCenterHome")
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width, height: 400)
                            .clipped()
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(1.1), Color.clear]),
                            startPoint: .bottom,
                            endPoint: .center
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BYU Fathers and Sons")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            if greeting.isEmpty {
                                Text(" ")
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
                    .ignoresSafeArea(edges: .top)
                    
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
                            isQuestOpen: $isQuestOpen,
                            selectedQuest: $selectedQuest // Pass binding
                        )
                        .environmentObject(profileVM)
                    }
                    
                    // MARK: Completed Quests Section
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
                            isQuestOpen: $isQuestOpen,
                            selectedQuest: $selectedQuest // Pass binding
                        )
                        .environmentObject(profileVM)
                    }
                    
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
                    
                    // Extra vertical spacing for scrolling
                    Color.clear
                        .frame(height: 300)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
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
                        completedQuestTitles = array
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
    }
}

struct ForYouSectionView: View {
    let quests: [Quest]
    let namespace: Namespace.ID
    @Binding var isQuestOpen: Bool
    @Binding var selectedQuest: Quest? // Added binding
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
                            NavigationLink {
                                QuestView(quest: quest, isQuestOpen: $isQuestOpen)
                                    .navigationTransition(.zoom(sourceID: "\(quest.id)", in: namespace))
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
                            .matchedTransitionSource(id: "\(quest.id)", in: namespace)
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
                                        FirebaseService.shared.deleteQuest(quest) { error in
                                            if let error = error {
                                                print("Failed to delete:", error.localizedDescription)
                                            } else {
                                                // Remove it locally so UI updates
                                                // Note: This will only update HomeView if passed as a Binding or via State
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    selectedQuest = quest // Set selected quest
                                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                                    generator.impactOccurred()
                                }
                            )
                        } else {
                            NavigationLink {
                                QuestView(quest: quest, isQuestOpen: $isQuestOpen)
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
                                        FirebaseService.shared.deleteQuest(quest) { error in
                                            if let error = error {
                                                print("Failed to delete:", error.localizedDescription)
                                            } else {
                                                // Remove it locally so UI updates
                                                // Note: This will only update HomeView if passed as a Binding or via State
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                                    generator.impactOccurred()
                                }
                            )
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
    @Binding var isQuestOpen: Bool
    @Binding var selectedQuest: Quest? // Added binding
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
                            NavigationLink {
                                QuestView(quest: quest, isQuestOpen: $isQuestOpen)
                                    .navigationTransition(.zoom(sourceID: "\(quest.id)", in: namespace))
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
                            .matchedTransitionSource(id: "\(quest.id)", in: namespace)
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
                                        FirebaseService.shared.deleteQuest(quest) { error in
                                            if let error = error {
                                                print("Failed to delete:", error.localizedDescription)
                                            } else {
                                                // Remove it locally so UI updates
                                                // Note: This will only update HomeView if passed as a Binding or via State
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    selectedQuest = quest // Set selected quest
                                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                                    generator.impactOccurred()
                                }
                            )
                        } else {
                            NavigationLink {
                                QuestView(quest: quest, isQuestOpen: $isQuestOpen)
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
                                        FirebaseService.shared.deleteQuest(quest) { error in
                                            if let error = error {
                                                print("Failed to delete:", error.localizedDescription)
                                            } else {
                                                // Remove it locally so UI updates
                                                // Note: This will only update HomeView if passed as a Binding or via State
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                                    generator.impactOccurred()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    @State static var isQuestOpen = false
    static var previews: some View {
        HomeView(isQuestOpen: $isQuestOpen, selectedQuest: .constant(nil))
            .environmentObject(ProfileViewModel())
    }
}
