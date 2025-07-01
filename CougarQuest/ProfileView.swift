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
    @State private var isEditingName = false
    @State private var isEditingPhone = false
    @State private var editingSonIndices = Set<Int>()

    private func updateFirestore(key: String, value: Any) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid)
            .updateData([key: value])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Parent Info")) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.cougarBlue)
                        if isEditingName {
                            VStack(alignment: .leading) {
                                TextField("First Name", text: $viewModel.firstName)
                                    .onSubmit {
                                        updateFirestore(key: "firstName", value: viewModel.firstName)
                                    }
                                TextField("Last Name", text: $viewModel.lastName)
                                    .onSubmit {
                                        updateFirestore(key: "lastName", value: viewModel.lastName)
                                    }
                            }
                        } else {
                            if viewModel.firstName.isEmpty && viewModel.lastName.isEmpty {
                                Text(viewModel.name)
                            } else {
                                Text("\(viewModel.firstName) \(viewModel.lastName)")
                            }
                        }
                        Spacer()
                        Button {
                            isEditingName.toggle()
                        } label: {
                            Image(systemName: isEditingName ? "checkmark" : "pencil")
                                .foregroundColor(.cougarBlue)
                        }
                    }
                    HStack {
                        // Determine whether to show phone or email
                        let hasPhone = !viewModel.rawPhone.isEmpty
                        let displayText = hasPhone
                            ? viewModel.rawPhone
                            : (Auth.auth().currentUser?.email ?? "")
                        let symbolName = hasPhone
                            ? "phone.fill"
                            : "envelope.fill"
                        let placeholder = hasPhone
                            ? "Phone Number"
                            : "Email"
                        
                        Image(systemName: symbolName)
                            .foregroundColor(.cougarBlue)
                        if isEditingPhone && hasPhone {
                            TextField(placeholder, text: $viewModel.rawPhone)
                                .keyboardType(.numberPad)
                                .onChange(of: viewModel.rawPhone) { newValue in
                                    viewModel.rawPhone = viewModel.formatPhone(newValue)
                                }
                                .onSubmit {
                                    guard let uid = Auth.auth().currentUser?.uid else { return }
                                    Firestore.firestore().collection("users").document(uid)
                                        .updateData(["phone": viewModel.rawPhone])
                                }
                        } else {
                            Text(displayText)
                        }
                        Spacer()
                        if hasPhone {
                            Button {
                                if isEditingPhone {
                                    guard let uid = Auth.auth().currentUser?.uid else { return }
                                    Firestore.firestore().collection("users").document(uid)
                                        .updateData(["phone": viewModel.rawPhone])
                                }
                                isEditingPhone.toggle()
                            } label: {
                                Image(systemName: isEditingPhone ? "checkmark" : "pencil")
                                    .foregroundColor(.cougarBlue)
                            }
                        }
                    }
                }
                Section(header: Text("Sons")) {
                    ForEach(viewModel.sons.indices, id: \.self) { idx in
                      HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.cougarBlue)
                        if editingSonIndices.contains(idx) {
                          TextField("Son \(idx+1)", text: $viewModel.sons[idx])
                            .onSubmit {
                              updateFirestore(key: "sons", value: viewModel.sons)
                              editingSonIndices.remove(idx)
                            }
                        } else {
                          Text(viewModel.sons[idx])
                        }

                        Spacer()

                        Button {
                          if editingSonIndices.contains(idx) {
                            // finish editing
                            editingSonIndices.remove(idx)
                          } else {
                            editingSonIndices.insert(idx)
                          }
                        } label: {
                          Image(systemName: editingSonIndices.contains(idx) ? "checkmark" : "pencil")
                            .foregroundColor(.cougarBlue)
                        }
                      }
                      .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                          viewModel.sons.remove(at: idx)
                          updateFirestore(key: "sons", value: viewModel.sons)
                        } label: {
                          Label("Delete", systemImage: "trash")
                        }
                      }
                    }
                    if viewModel.sons.count < viewModel.maxSons {
                        Button {
                            viewModel.sons.append("")
                            let newIdx = viewModel.sons.count - 1
                            editingSonIndices = [newIdx]
                            guard let uid = Auth.auth().currentUser?.uid else { return }
                            Firestore.firestore().collection("users").document(uid)
                                .updateData(["sons": viewModel.sons])
                        } label: {
                            Label("Add Son", systemImage: "plus.circle")
                                .foregroundColor(.cougarBlue)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.signOut(authVM: authVM)
                    } label: {
                        Text("Log Out")
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                // trigger load to refresh remote data
                viewModel.load()
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(ProfileViewModel())
}
