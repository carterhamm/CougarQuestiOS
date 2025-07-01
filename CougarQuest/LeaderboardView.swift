//
//  LeaderboardView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 5/11/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var profileVM: ProfileViewModel
    @State private var showSheet = false
    
    var body: some View {
        ZStack {
            (colorScheme == .dark
                ? Color.black
                : appleLightGray)
                .edgesIgnoringSafeArea(.all)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Leaderboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        showSheet = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.largeTitle)
                            .foregroundColor(Color.cougarBlue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 40)
                
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 16) {
                            let rank = viewModel.userRank ?? 0
                            let ordinalSuffix: String = {
                                switch rank % 100 {
                                case 11, 12, 13: return "th"
                                default:
                                    switch rank % 10 {
                                    case 1: return "st"
                                    case 2: return "nd"
                                    case 3: return "rd"
                                    default: return "th"
                                    }
                                }
                            }()
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.7)
                                    .frame(
                                        width: geometry.size.width * 0.9,
                                        height: geometry.size.width * 0.9 * 0.47
                                    )
                                VStack(spacing: 4) {
                                    Spacer()
                                    HStack {
                                        Text("Currently")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color.cougarBlue)
                                            .padding(.horizontal, 20)
                                            .padding(.bottom, 1)
                                        Spacer()
                                    }
                                    HStack {
                                        Text("\(rank)\(ordinalSuffix) Place")
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color.cougarBlue)
                                            .padding(.leading, 20)
                                            .padding (.bottom, 34)
                                        Spacer()
                                    }
                                }
                            }
                            .frame(
                                width: geometry.size.width * 0.9,
                                height: geometry.size.width * 0.9 * 0.36
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        colorScheme == .dark
                                            ? Color(UIColor.darkGray)
                                            : Color(UIColor.lightGray),
                                        lineWidth: 1
                                    )
                            )
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.7)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                colorScheme == .dark
                                                    ? Color(UIColor.darkGray)
                                                    : Color(UIColor.lightGray),
                                                lineWidth: 1
                                            )
                                    )
                                
                                VStack(spacing: 16) {
                                    ForEach(Array(viewModel.users.enumerated()), id: \.element.id) { index, user in
                                        let isCurrent = user.id == Auth.auth().currentUser?.uid
                                        HStack {
                                            Text("\(index + 1)")
                                                .fontWeight(.black)
                                                .foregroundColor(
                                                    isCurrent
                                                        ? Color.cougarBlue
                                                        : (colorScheme == .dark ? .white : .black)
                                                )
                                            Spacer().frame(width: 20)
                                            Text(user.displayName)
                                                .fontWeight(.semibold)
                                                .foregroundColor(
                                                    isCurrent
                                                        ? Color.cougarBlue
                                                        : (colorScheme == .dark ? .white : .black)
                                                )
                                            Spacer()
                                            Text("\(user.points)")
                                                .foregroundColor(Color.cougarBlue)
                                                .fontWeight(.heavy)
                                                .padding(.trailing, 3)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 24)
                                        
                                        if index < viewModel.users.count - 1 {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .padding(.vertical, 11)
                            }
                            .frame(width: geometry.size.width * 0.9)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            Color.clear
                                .frame(height: 200)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top)
                    }
                    .refreshable {
                        viewModel.fetchLeaderboard()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSheet) {
            if profileVM.isAdmin {
                SortingView()
            } else {
                ProfileView()
            }
        }
        .onAppear { viewModel.fetchLeaderboard() }
    }
}

class LeaderboardViewModel: ObservableObject {
    struct LeaderboardUser: Identifiable {
        let id: String
        let displayName: String
        let points: Int
    }
    
    @Published var users: [LeaderboardUser] = []
    @Published var userRank: Int?
    private let db = Firestore.firestore()
    private let currentUID = Auth.auth().currentUser?.uid
    
    func fetchLeaderboard() {
        db.collection("users")
          .order(by: "points", descending: true)
          .getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            
            var temp: [LeaderboardUser] = []
            for (index, doc) in docs.enumerated() {
                let data = doc.data()
                // Team-name override
                let teamName = (data["teamName"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                var displayName: String

                if !teamName.isEmpty {
                    displayName = teamName
                } else {
                    // Base names: first name or fallback
                    let firstName = (data["firstName"] as? String ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallbackName = (data["name"] as? String ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let primaryName = firstName.isEmpty ? fallbackName : firstName

                    // Include sons
                    let sons = (data["sons"] as? [String] ?? [])
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    // Build list, inserting grandpa if present
                    var allNames = [primaryName] + sons
                    let grandpa = (data["grandpa"] as? String ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !grandpa.isEmpty {
                        allNames.insert(grandpa, at: 0)
                    }

                    // Format as a comma-separated or "and" list
                    switch allNames.count {
                    case 0:
                        displayName = "Unnamed user"
                    case 1:
                        displayName = allNames[0]
                    case 2:
                        displayName = "\(allNames[0]) and \(allNames[1])"
                    default:
                        let head = allNames.dropLast().joined(separator: ", ")
                        let last = allNames.last!
                        displayName = "\(head), and \(last)"
                    }
                    // Fallback if somehow still empty
                    if displayName.isEmpty {
                        displayName = "Unnamed user"
                    }
                }
                let pts = data["points"] as? Int ?? 0
                
                temp.append(.init(id: doc.documentID,
                                  displayName: displayName,
                                  points: pts))
                
                if doc.documentID == self.currentUID {
                    DispatchQueue.main.async {
                        self.userRank = index + 1
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.users = temp
            }
          }
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardView()
            .environmentObject(ProfileViewModel())
    }
}
