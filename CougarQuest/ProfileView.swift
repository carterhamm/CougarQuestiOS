//
//  ProfileView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 5/1/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var viewModel: ProfileViewModel
    @ObservedObject private var morphState = MorphState.shared
    @ObservedObject private var iconManager = AppIconManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var isEditingName = false
    @State private var isEditingPhone = false
    @State private var editingSonIndices = Set<Int>()
    @State private var editingTeamName = false
    @State private var points: Int = 0
    @State private var showLogOutConfirm = false

    private func updateFirestore(key: String, value: Any) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid)
            .updateData([key: value])
    }

    private var displayName: String {
        if !viewModel.firstName.isEmpty || !viewModel.lastName.isEmpty {
            return "\(viewModel.firstName) \(viewModel.lastName)".trimmingCharacters(in: .whitespaces)
        }
        return viewModel.name.isEmpty ? "Unnamed" : viewModel.name
    }

    private var initials: String {
        let names = displayName.split(separator: " ")
        let parts = names.prefix(2).compactMap { $0.first.map(String.init) }
        return parts.joined().uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroCard
                        teamCard
                        parentInfoCard
                        sonsCard
                        appIconCard
                        logOutButton
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.load()
                fetchPoints()
            }
            .confirmationDialog(
                "Log out of CougarQuest?",
                isPresented: $showLogOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    viewModel.signOut(authVM: authVM)
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 14) {
            // Avatar — glass-tinted circle (matches the rest of the app's
            // AdaptiveGlass language; less harsh than the previous solid
            // border).
            ZStack {
                Color.clear
                    .frame(width: 88, height: 88)
                    .adaptiveGlassEffectTinted(
                        color: Color.cougarBlue.opacity(0.18),
                        in: Circle()
                    )
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.cougarBlue)
            }

            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                if !viewModel.teamName.isEmpty {
                    Text(viewModel.teamName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Stats row
            HStack(spacing: 12) {
                statTile(value: "\(points)", label: "Points", systemImage: "star.fill")
                statTile(value: "\(morphState.completedQuestTitles.count)", label: "Completed", systemImage: "checkmark.seal.fill")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .adaptiveGlassEffect(
            in: RoundedRectangle(cornerRadius: 24),
            strokeColor: Color.cougarBlue.opacity(0.25),
            strokeWidth: 1
        )
    }

    private func statTile(value: String, label: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundColor(.cougarBlue)
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }
            Text(label.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .adaptiveGlassEffectTinted(color: Color.cougarBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Team Card

    private var teamCard: some View {
        cardContainer(title: "Team", icon: "person.3.fill") {
            HStack {
                if editingTeamName {
                    TextField("Team Name", text: $viewModel.teamName)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            updateFirestore(key: "teamName", value: viewModel.teamName)
                            editingTeamName = false
                        }
                } else {
                    Text(viewModel.teamName.isEmpty ? "Add a team name" : viewModel.teamName)
                        .foregroundColor(viewModel.teamName.isEmpty ? .secondary : .primary)
                }
                Spacer()
                Button {
                    if editingTeamName {
                        updateFirestore(key: "teamName", value: viewModel.teamName)
                    }
                    editingTeamName.toggle()
                } label: {
                    Image(systemName: editingTeamName ? "checkmark" : "pencil")
                        .foregroundColor(.cougarBlue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Parent Info

    private var parentInfoCard: some View {
        cardContainer(title: "Parent Info", icon: "person.fill") {
            VStack(spacing: 14) {
                rowDivider {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.cougarBlue)
                            .frame(width: 22)
                        if isEditingName {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("First Name", text: $viewModel.firstName)
                                    .onSubmit { updateFirestore(key: "firstName", value: viewModel.firstName) }
                                TextField("Last Name", text: $viewModel.lastName)
                                    .onSubmit { updateFirestore(key: "lastName", value: viewModel.lastName) }
                            }
                        } else {
                            Text(displayName)
                        }
                        Spacer()
                        Button {
                            if isEditingName {
                                updateFirestore(key: "firstName", value: viewModel.firstName)
                                updateFirestore(key: "lastName", value: viewModel.lastName)
                            }
                            isEditingName.toggle()
                        } label: {
                            Image(systemName: isEditingName ? "checkmark" : "pencil")
                                .foregroundColor(.cougarBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                let hasPhone = !viewModel.rawPhone.isEmpty
                HStack {
                    Image(systemName: hasPhone ? "phone.fill" : "envelope.fill")
                        .foregroundColor(.cougarBlue)
                        .frame(width: 22)
                    if isEditingPhone && hasPhone {
                        TextField("Phone Number", text: $viewModel.rawPhone)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.rawPhone) { newValue in
                                viewModel.rawPhone = viewModel.formatPhone(newValue)
                            }
                            .onSubmit {
                                updateFirestore(key: "phoneNumber", value: viewModel.rawPhone)
                            }
                    } else {
                        Text(hasPhone ? viewModel.rawPhone : (Auth.auth().currentUser?.email ?? "—"))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    if hasPhone {
                        Button {
                            if isEditingPhone {
                                updateFirestore(key: "phoneNumber", value: viewModel.rawPhone)
                            }
                            isEditingPhone.toggle()
                        } label: {
                            Image(systemName: isEditingPhone ? "checkmark" : "pencil")
                                .foregroundColor(.cougarBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Sons

    private var sonsCard: some View {
        cardContainer(title: "Sons", icon: "person.2.fill") {
            VStack(spacing: 12) {
                ForEach(Array(viewModel.sons.enumerated()), id: \.offset) { idx, _ in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.cougarBlue)
                            .frame(width: 22)
                        if editingSonIndices.contains(idx) {
                            TextField("Son \(idx + 1)", text: $viewModel.sons[idx])
                                .onSubmit {
                                    updateFirestore(key: "sons", value: viewModel.sons)
                                    editingSonIndices.remove(idx)
                                }
                        } else {
                            Text(viewModel.sons[idx].isEmpty ? "Son \(idx + 1)" : viewModel.sons[idx])
                                .foregroundColor(viewModel.sons[idx].isEmpty ? .secondary : .primary)
                        }
                        Spacer()
                        Button {
                            if editingSonIndices.contains(idx) {
                                updateFirestore(key: "sons", value: viewModel.sons)
                                editingSonIndices.remove(idx)
                            } else {
                                editingSonIndices.insert(idx)
                            }
                        } label: {
                            Image(systemName: editingSonIndices.contains(idx) ? "checkmark" : "pencil")
                                .foregroundColor(.cougarBlue)
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive) {
                            viewModel.sons.remove(at: idx)
                            editingSonIndices.remove(idx)
                            updateFirestore(key: "sons", value: viewModel.sons)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.sons.count < viewModel.maxSons {
                    Button {
                        viewModel.sons.append("")
                        let newIdx = viewModel.sons.count - 1
                        editingSonIndices = [newIdx]
                        updateFirestore(key: "sons", value: viewModel.sons)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Son")
                            Spacer()
                        }
                        .foregroundColor(.cougarBlue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - App Icon Picker

    private var appIconCard: some View {
        cardContainer(title: "App Icon", icon: "app.dashed") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick your home-screen look. Available in the full app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    ForEach(AppIconOption.all) { option in
                        appIconChoice(option: option)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func appIconChoice(option: AppIconOption) -> some View {
        let isSelected = iconManager.current.id == option.id
        Button {
            Task { await iconManager.select(option) }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 72, height: 72)
                    if let assetName = option.previewAssetName,
                       let img = UIImage(named: assetName) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        // Fallback when no preview asset is in the bundle yet.
                        Text(String(option.displayName.prefix(1)))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.cougarBlue)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? Color.cougarBlue : Color.clear, lineWidth: 3)
                )

                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cougarBlue)
                            .font(.caption)
                    }
                    Text(option.displayName)
                        .font(.caption)
                        .fontWeight(isSelected ? .bold : .medium)
                        .foregroundColor(isSelected ? .cougarBlue : .primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Log Out

    private var logOutButton: some View {
        Button {
            showLogOutConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Log Out")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .adaptiveGlassEffectTinted(
                color: Color.red.opacity(0.10),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func cardContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.cougarBlue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveGlassEffect(
            in: RoundedRectangle(cornerRadius: 20),
            strokeColor: Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.12),
            strokeWidth: 1
        )
    }

    @ViewBuilder
    private func rowDivider<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 14) {
            content()
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func fetchPoints() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, _ in
            DispatchQueue.main.async {
                points = snapshot?.data()?["points"] as? Int ?? 0
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(ProfileViewModel())
}
