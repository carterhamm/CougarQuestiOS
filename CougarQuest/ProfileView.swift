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
    @State private var showDeleteAccountConfirm = false
    @State private var deleteError: String?

    private enum EditFocus: Hashable { case name, phone, son(Int), teamName }
    @FocusState private var focusedField: EditFocus?

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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            if let url = URL(string: "mailto:support@cougarquest.com?subject=CougarQuest%20Support") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Help & Support", systemImage: "questionmark.circle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteAccountConfirm = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(colorScheme == .dark ? .white : .cougarBlue)
                    }
                }
            }
            .onAppear {
                viewModel.load()
                fetchPoints()
            }
            .alert("Log out of CougarQuest?", isPresented: $showLogOutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    viewModel.signOut(authVM: authVM)
                }
            } message: {
                Text("You'll need to sign back in to see your quests and points.")
            }
            .alert("Delete your account?", isPresented: $showDeleteAccountConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This permanently removes your profile, points, and quest history. This cannot be undone.")
            }
            .alert("Couldn't delete account", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            ), presenting: deleteError) { _ in
                Button("OK", role: .cancel) { deleteError = nil }
            } message: { msg in
                Text(msg)
            }
        }
    }

    /// Hard-deletes the user's Firestore profile and Auth record.
    /// Apple App Store guidelines require this to be available in-app.
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let firestore = Firestore.firestore()
        firestore.collection("users").document(uid).delete { firestoreErr in
            if let firestoreErr = firestoreErr {
                deleteError = "Profile delete failed: \(firestoreErr.localizedDescription)"
                return
            }
            user.delete { authErr in
                DispatchQueue.main.async {
                    if let authErr = authErr {
                        // Apple may require recent re-auth for delete — surface that clearly.
                        deleteError = "Auth delete failed: \(authErr.localizedDescription). Please sign out and sign back in, then try again."
                        return
                    }
                    authVM.isSignedIn = false
                }
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        Group {
            if #available(iOS 26.0, *) {
                heroCardGlass
            } else {
                heroCardLegacy
            }
        }
    }

    @available(iOS 26.0, *)
    private var heroCardGlass: some View {
        // No outer card glass — that hides/cancels the avatar's glass effect.
        // Just the avatar gets the Liquid Glass treatment, sitting on the plain
        // ProfileView background where its refraction + tint are clearly visible.
        VStack(spacing: 14) {
            Color.clear
                .frame(width: 96, height: 96)
                .glassEffect(
                    .regular.tint(Color.cougarBlue.opacity(0.55)),
                    in: Circle()
                )
                .overlay(
                    Text(initials.isEmpty ? "?" : initials)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                )

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
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                statTile(value: "\(points)", label: "Points", systemImage: "star.fill")
                statTile(value: "\(morphState.completedQuestTitles.count)", label: "Completed", systemImage: "checkmark.seal.fill")
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private var heroCardLegacy: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(Color.cougarBlue.opacity(0.18))
                    .frame(width: 88, height: 88)
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
        // Material backing + subtle CougarBlue tint. Same reason as the
        // avatar: visibly glass even when nested inside the heroCard.
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cougarBlue.opacity(0.10))
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)
                )
        )
    }

    // MARK: - Team Card

    private var teamCard: some View {
        cardContainer(title: "Team", icon: "person.3.fill") {
            HStack {
                if editingTeamName {
                    TextField("Team Name", text: $viewModel.teamName)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .teamName)
                        .onSubmit {
                            updateFirestore(key: "teamName", value: viewModel.teamName)
                            editingTeamName = false
                            focusedField = nil
                        }
                } else {
                    Text(viewModel.teamName.isEmpty ? "Add a team name" : viewModel.teamName)
                        .foregroundColor(viewModel.teamName.isEmpty ? .secondary : .primary)
                }
                Spacer()
                Button {
                    if editingTeamName {
                        updateFirestore(key: "teamName", value: viewModel.teamName)
                        editingTeamName = false
                        focusedField = nil
                    } else {
                        editingTeamName = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusedField = .teamName
                        }
                    }
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
                                    .focused($focusedField, equals: .name)
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
                                isEditingName = false
                                focusedField = nil
                            } else {
                                isEditingName = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    focusedField = .name
                                }
                            }
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
                            .focused($focusedField, equals: .phone)
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
                                isEditingPhone = false
                                focusedField = nil
                            } else {
                                isEditingPhone = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    focusedField = .phone
                                }
                            }
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
                // Empty-state CTA when the parent hasn't added any sons yet.
                if viewModel.sons.isEmpty {
                    Button {
                        let g = UIImpactFeedbackGenerator(style: .light); g.impactOccurred()
                        viewModel.sons.append("")
                        editingSonIndices = [0]
                        updateFirestore(key: "sons", value: viewModel.sons)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusedField = .son(0)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.badge.plus")
                                .font(.system(size: 28))
                                .foregroundColor(.cougarBlue)
                            Text("Add your sons")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.cougarBlue)
                            Text("Show who's on your team.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    Color.cougarBlue.opacity(0.45),
                                    style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(Array(viewModel.sons.enumerated()), id: \.offset) { idx, _ in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.cougarBlue)
                            .frame(width: 22)
                        if editingSonIndices.contains(idx) {
                            TextField("Son \(idx + 1)", text: $viewModel.sons[idx])
                                .focused($focusedField, equals: .son(idx))
                                .onSubmit {
                                    updateFirestore(key: "sons", value: viewModel.sons)
                                    editingSonIndices.remove(idx)
                                    focusedField = nil
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
                                focusedField = nil
                            } else {
                                editingSonIndices.insert(idx)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    focusedField = .son(idx)
                                }
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
            // Make the entire pill (including the padded area, not just
            // the icon + text) the tap target.
            .contentShape(Capsule())
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
                // Per-season points (current season only). Falls back to the
                // legacy total for users whose docs haven't been backfilled.
                let data = snapshot?.data()
                points = (data?["currentSeasonPoints"] as? Int)
                    ?? (data?["points"] as? Int)
                    ?? 0
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(ProfileViewModel())
}
