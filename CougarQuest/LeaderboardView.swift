//
//  LeaderboardView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 5/11/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Main View

struct LeaderboardView: View {
    // Hoisted to a shared singleton (instantiated at app launch by ContentView)
    // so Firestore fetch starts BEFORE the user first taps the Standings tab.
    // Eliminates the brief freeze when transitioning from Quests → Standings.
    @ObservedObject private var viewModel = LeaderboardViewModel.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : appleLightGray)
                .ignoresSafeArea()

            // Empty state lives OUTSIDE the ScrollView so it can center on
            // the actual viewport — a ScrollView's child only knows its own
            // content size, which made `.padding(.top, 80)` the best we
            // could do before. ZStack centers by default.
            if viewModel.users.isEmpty && viewModel.hasLoaded {
                VStack(spacing: 22) {
                    // Trophy in a tinted glass medallion — gives the empty
                    // state real visual weight instead of a lonely icon.
                    Color.clear
                        .frame(width: 120, height: 120)
                        .adaptiveGlassEffectTinted(
                            color: Color.cougarBlue.opacity(0.22),
                            in: Circle()
                        )
                        .overlay(
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.cougarBlue)
                        )

                    VStack(spacing: 8) {
                        Text("The Leaderboard")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.cougarBlue)
                        Text("Awaits its first champion.")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.cougarBlue.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

                    Text("Complete a quest to claim the top spot.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.horizontal, 32)
            } else if viewModel.users.isEmpty {
                ProgressView()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if viewModel.users.count >= 1 {
                            PodiumSection(
                                users: Array(viewModel.users.prefix(3)),
                                currentUID: Auth.auth().currentUser?.uid
                            )
                        }

                        if let rank = viewModel.userRank, let entry = viewModel.currentUserEntry {
                            MyRankCard(rank: rank, points: entry.points)
                        }

                        RankingsList(
                            users: viewModel.users,
                            currentUID: Auth.auth().currentUser?.uid
                        )
                    }
                }
                .refreshable { viewModel.fetchLeaderboard() }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.fetchLeaderboard() }
    }
}

// MARK: - Podium

private struct PodiumSection: View {
    let users: [LeaderboardViewModel.LeaderboardUser]
    let currentUID: String?

    // Layout order: 2nd (left), 1st (center), 3rd (right)
    private var slots: [(rank: Int, idx: Int, height: CGFloat)] {
        [(2, 1, 72), (1, 0, 100), (3, 2, 52)]
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(slots, id: \.rank) { slot in
                let user: LeaderboardViewModel.LeaderboardUser? = users.indices.contains(slot.idx) ? users[slot.idx] : nil
                let isCurrent = user?.id == currentUID

                VStack(spacing: 6) {
                    Text(medalEmoji(slot.rank))
                        .font(.system(size: 28))

                    if let user = user {
                        Text(user.displayName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.55)
                            .foregroundColor(isCurrent ? .cougarBlue : .primary)

                        Text("\(user.points) pts")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(height: slot.height)
                            .adaptiveGlassEffectTinted(
                                color: podiumColor(slot.rank),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )

                        Text("\(slot.rank)")
                            .font(.headline)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private func medalEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }

    private func podiumColor(_ rank: Int) -> Color {
        // Brand-consistent CougarBlue with descending intensity for 1st/2nd/3rd
        // (gold/silver/bronze felt out of place against the rest of the app).
        switch rank {
        case 1: return Color.cougarBlue
        case 2: return Color.cougarBlue.opacity(0.75)
        case 3: return Color.cougarBlue.opacity(0.55)
        default: return Color.cougarBlue.opacity(0.4)
        }
    }

    private func podiumName(_ name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return String(first.prefix(12))
    }
}

// MARK: - Your Rank Card

private struct MyRankCard: View {
    let rank: Int
    let points: Int
    @Environment(\.colorScheme) var colorScheme

    private var ordinal: String {
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
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR RANK")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(rank)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.cougarBlue)
                    Text("\(ordinal) place")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.cougarBlue)
                        .padding(.bottom, 4)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("POINTS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("\(points)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.cougarBlue)
            }
        }
        .padding(20)
        .adaptiveGlassEffect(
            in: RoundedRectangle(cornerRadius: 20),
            strokeColor: Color.cougarBlue.opacity(0.25),
            strokeWidth: 1
        )
        .padding(.horizontal)
    }
}

// MARK: - Rankings List

private struct RankingsList: View {
    let users: [LeaderboardViewModel.LeaderboardUser]
    let currentUID: String?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // LazyVStack so 200+ rows aren't all materialized at once — only
        // the visible (and just-off-screen) rows render their AdaptiveGlass
        // backgrounds, which are GPU-expensive at scale.
        LazyVStack(spacing: 10) {
            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                RankingRow(
                    rank: index + 1,
                    user: user,
                    isCurrent: user.id == currentUID
                )
            }
        }
        .padding(.horizontal)
    }
}

private struct RankingRow: View {
    let rank: Int
    let user: LeaderboardViewModel.LeaderboardUser
    let isCurrent: Bool
    @Environment(\.colorScheme) var colorScheme

    private var rankBadgeColor: Color {
        // CougarBlue across all ranks; intensity drops slightly past top 3
        // so the visual hierarchy still hints at the leader without using
        // off-brand gold/silver/bronze colors.
        switch rank {
        case 1: return Color.cougarBlue
        case 2: return Color.cougarBlue.opacity(0.85)
        case 3: return Color.cougarBlue.opacity(0.7)
        default: return Color.cougarBlue.opacity(0.55)
        }
    }

    private var rankTextColor: Color {
        .white
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Color.clear
                    .frame(width: 36, height: 36)
                    .adaptiveGlassEffectTinted(color: rankBadgeColor, in: Circle())
                Text("\(rank)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(rankTextColor)
            }

            Text(user.displayName)
                .font(.subheadline)
                .fontWeight(isCurrent ? .bold : .semibold)
                .foregroundColor(isCurrent ? .white : .primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text("\(user.points)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(isCurrent ? .white : .cougarBlue)
                Text("pts")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrent ? .white.opacity(0.85) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .adaptiveGlassEffectTinted(
                color: isCurrent ? Color.white.opacity(0.22) : Color.cougarBlue.opacity(0.18),
                in: Capsule()
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.cougarBlue)
            } else {
                Color.clear
                    .adaptiveGlassEffect(
                        in: RoundedRectangle(cornerRadius: 18),
                        strokeColor: Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.12),
                        strokeWidth: 1
                    )
            }
        }
        .overlay(
            Group {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.cougarBlue.opacity(0.35), lineWidth: 1)
                }
            }
        )
    }
}

// MARK: - ViewModel

class LeaderboardViewModel: ObservableObject {
    static let shared = LeaderboardViewModel()

    struct LeaderboardUser: Identifiable {
        let id: String
        let displayName: String
        let points: Int
    }

    @Published var users: [LeaderboardUser] = []
    @Published var userRank: Int?
    @Published var hasLoaded: Bool = false   // true after first fetch completes (success or empty)

    private let db = Firestore.firestore()
    private var currentUID: String? { Auth.auth().currentUser?.uid }
    private var hasPrefetched = false

    /// Fire-and-forget prefetch from app launch; no-op after first call.
    /// Use `fetchLeaderboard()` for explicit refreshes (pull-to-refresh).
    func prefetchIfNeeded() {
        guard !hasPrefetched else { return }
        hasPrefetched = true
        fetchLeaderboard()
    }

    var currentUserEntry: LeaderboardUser? {
        guard let uid = currentUID else { return nil }
        return users.first(where: { $0.id == uid })
    }

    /// Hard-coded season start. Users created before this date AND users
    /// with zero current-season points are filtered out of the leaderboard.
    private static let seasonStart: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 15
        return Calendar.current.date(from: c) ?? Date.distantPast
    }()

    func fetchLeaderboard() {
        // Fetch all users, filter and sort in-memory. We avoid Firestore's
        // order(by:) because it silently drops docs missing the field.
        db.collection("users")
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }

                var temp: [LeaderboardUser] = []
                for doc in docs {
                    let data = doc.data()

                    // Filter 1: only current-season users.
                    // createdAt is a Timestamp set on first signup. Anyone
                    // who joined before seasonStart is from a prior year
                    // and shouldn't appear in this season's rankings.
                    guard let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          createdAt >= Self.seasonStart else { continue }

                    // Filter 2: hide zero-point users until they score.
                    let pts = data["currentSeasonPoints"] as? Int ?? 0
                    guard pts > 0 else { continue }

                    let teamName = (data["teamName"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    var displayName: String

                    if !teamName.isEmpty {
                        displayName = teamName
                    } else {
                        let firstName = (data["firstName"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let fallback  = (data["name"]      as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let primary   = firstName.isEmpty ? fallback : firstName

                        let sons = (data["sons"] as? [String] ?? [])
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }

                        var allNames = [primary] + sons
                        let grandpa = (data["grandpa"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !grandpa.isEmpty { allNames.insert(grandpa, at: 0) }

                        switch allNames.count {
                        case 0:       displayName = "Unnamed user"
                        case 1:       displayName = allNames[0]
                        case 2:       displayName = "\(allNames[0]) & \(allNames[1])"
                        default:
                            let head = allNames.dropLast().joined(separator: ", ")
                            displayName = "\(head) & \(allNames.last!)"
                        }
                        if displayName.isEmpty { displayName = "Unnamed user" }
                    }

                    temp.append(.init(id: doc.documentID, displayName: displayName, points: pts))
                }

                temp.sort { $0.points > $1.points }

                for (index, user) in temp.enumerated() where user.id == self.currentUID {
                    DispatchQueue.main.async { self.userRank = index + 1 }
                }

                DispatchQueue.main.async {
                    self.users = temp
                    self.hasLoaded = true
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
