//
//  SortingView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/27/25.
//

import SwiftUI
import FirebaseAuth

struct SortingView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: ProfileView()) {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    NavigationLink(destination: AddQuestView()) {
                        Label("Add Quest", systemImage: "plus.circle")
                    }
                }
                Section {
                    Button(action: {
                        do {
                            try Auth.auth().signOut()
                            authVM.isSignedIn = false
                        } catch {}
                    }) {
                        Label("Log Out", systemImage: "arrow.backward.circle")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
        }
        .accentColor(.cougarBlue)
    }
}

#Preview {
    SortingView()
}
