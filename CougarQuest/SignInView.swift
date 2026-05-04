//
//  SignInView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/27/25.
//

import SwiftUI
import FirebaseCore       // for FirebaseApp.configure()
import FirebaseAuth       // for Auth & GoogleAuthProvider
import GoogleSignIn       // for GIDSignIn
import AuthenticationServices
import FirebaseFirestore
import Firebase
import FirebaseMessaging
import UserNotifications

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let authVM: AuthViewModel
    @Binding var errorMessage: String?
    
    init(authVM: AuthViewModel, errorMessage: Binding<String?>) {
        self.authVM = authVM
        self._errorMessage = errorMessage
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let identityTokenData = appleIDCredential.identityToken,
            let idTokenString = String(data: identityTokenData, encoding: .utf8)
        else { return }
        
        let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: "")
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = "Firebase sign-in error: \(error.localizedDescription)"
                return
            }
            guard let user = authResult?.user else { return }
            
            let uid = user.uid
            let email = appleIDCredential.email ?? user.email ?? ""
            let givenName = appleIDCredential.fullName?.givenName
            let familyName = appleIDCredential.fullName?.familyName
            
            let fullName: String = {
                if let g = givenName, let f = familyName {
                    return "\(g) \(f)"
                } else if let displayName = user.displayName {
                    return displayName
                } else {
                    return ""
                }
            }()
            
            // Update Firebase profile
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = fullName
            changeRequest.commitChanges { _ in
                // Firestore existence check & write
                let userRef = Firestore.firestore().collection("users").document(uid)
                userRef.getDocument { snapshot, error in
                    if let error = error {
                        print("Error fetching user document: \(error)")
                        return
                    }
                    if let snapshot = snapshot, snapshot.exists {
                        // Existing user → finish sign-in
                        DispatchQueue.main.async {
                            self.authVM.isSignedIn = true
                        }
                    } else {
                        // New user → send to registration flow
                        DispatchQueue.main.async {
                            // Binding injected from SignInView:
                            NotificationCenter.default.post(name: .navigateToRegister,
                                                            object: nil,
                                                            userInfo: ["skipPhone": true])
                        }
                        return
                    }
                    // Optional: update fields & FCM token
                    var fieldsToUpdate: [String: Any] = [
                        "email": email
                    ]
                    if !fullName.isEmpty {
                        fieldsToUpdate["name"] = fullName
                    }
                    if let g = givenName {
                        fieldsToUpdate["firstName"] = g
                    }
                    if let f = familyName {
                        fieldsToUpdate["lastName"] = f
                    }
                    userRef.setData(fieldsToUpdate, merge: true)
                    Messaging.messaging().token { token, error in
                        if let token = token {
                            userRef.setData(["fcmToken": token], merge: true)
                        }
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
    }
}

struct SignInView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    @State private var appleCoordinator: AppleSignInCoordinator?
    @State private var navigateToRegister = false
    @State private var registerSkipPhoneStep = false
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    private func updateFCMToken() {
        guard let user = Auth.auth().currentUser else { return }
        Messaging.messaging().token { token, error in
            if let token = token {
                let userRef = Firestore.firestore().collection("users").document(user.uid)
                userRef.setData(["fcmToken": token], merge: true)
            } else if let error = error {
                print("FCM token error:", error.localizedDescription)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)

                    // App icon as the splash logo — full-color rendered
                    // BYU Fathers and Sons design (the AppIconPreview asset
                    // I generated earlier is the same image as the home-
                    // screen icon, just at a flat rasterized size).
                    Image("AppIconPreview")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: Color.cougarBlue.opacity(0.25), radius: 22, x: 0, y: 10)

                    VStack(spacing: 4) {
                        Text("Welcome to")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text("CougarQuest")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cougarBlue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    Text("BYU Fathers and Sons")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Larger spacer pushes the auth buttons further down so
                    // the "Welcome to CougarQuest" hero has more breathing
                    // room above them.
                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        // Phone — neutral glass tint
                        NavigationLink(destination: RegisterView(skipPhoneStep: false)) {
                            Label("Continue with Phone Number", systemImage: "phone.fill")
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .adaptiveGlassEffectTinted(
                                    color: Color.gray.opacity(0.18),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)

                        // Apple — black/white inversion through glass
                        Button {
                            registerSkipPhoneStep = true
                            performAppleSignIn()
                        } label: {
                            Label("Continue with Apple", systemImage: "applelogo")
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .adaptiveGlassEffectTinted(
                                    color: colorScheme == .dark ? Color.white : Color.black,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)

                        // Google — CougarBlue glass
                        Button {
                            registerSkipPhoneStep = true
                            performGoogleSignIn()
                        } label: {
                            Label("Continue with Google", systemImage: "globe")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .adaptiveGlassEffectTinted(
                                    color: Color.cougarBlue,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                
                NavigationLink(
                    destination: RegisterView(skipPhoneStep: registerSkipPhoneStep),
                    isActive: $navigateToRegister
                ) {
                    EmptyView()
                }
            }
            .onAppear {
                requestNotificationPermissions()
                // Observe notification for Apple flow
                NotificationCenter.default.addObserver(forName: .navigateToRegister, object: nil, queue: .main) { note in
                    if let info = note.userInfo as? [String:Bool],
                       let skip = info["skipPhone"] {
                        registerSkipPhoneStep = skip
                        navigateToRegister = true
                    }
                }
            }
        }
    }
    
    // MARK: - Google Sign In
    private func performGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "❌ Missing clientID"
            return
        }
        guard let root = UIApplication.rootViewController else {
            errorMessage = "❌ No root view controller"
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error = error {
                errorMessage = "Google sign-in failed: \(error.localizedDescription)"
                return
            }
            guard let result = result, let idTokenObj = result.user.idToken else {
                errorMessage = "❌ Missing Google tokens"
                return
            }
            // Extract profile data directly from Google result
            let resultGiven = result.user.profile?.givenName ?? ""
            let resultFamily = result.user.profile?.familyName ?? ""
            let fullName = [resultGiven, resultFamily].filter { !$0.isEmpty }.joined(separator: " ")
            let emailFromGoogle = result.user.profile?.email ?? ""
            let credential = GoogleAuthProvider.credential(
                withIDToken: idTokenObj.tokenString,
                accessToken: result.user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, authError in
                if let authError = authError {
                    errorMessage = "Firebase sign-in error: \(authError.localizedDescription)"
                    return
                }
                guard let user = Auth.auth().currentUser else { return }
                // Fallback to Firebase displayName if Google profile familyName is empty
                let displayNameFallback = user.displayName ?? ""
                let fallbackParts = displayNameFallback.split(separator: " ", maxSplits: 1).map(String.init)
                let givenNameFinal = resultGiven.isEmpty ? (fallbackParts.first ?? "") : resultGiven
                let familyNameFinal = resultFamily.isEmpty ? (fallbackParts.count > 1 ? fallbackParts[1] : "") : resultFamily
                let fullNameFinal = [givenNameFinal, familyNameFinal].filter { !$0.isEmpty }.joined(separator: " ")
                let uid = user.uid
                let email = emailFromGoogle
                let userRef = Firestore.firestore().collection("users").document(uid)
                
                userRef.getDocument { snapshot, error in
                    if let error = error {
                        print("Error fetching user document: \(error)")
                        return
                    }
                    if let snapshot = snapshot, snapshot.exists {
                        // Existing user → finish sign-in
                        DispatchQueue.main.async {
                            authVM.isSignedIn = true
                        }
                    } else {
                        // New user → write email/name fields to Firestore, then send to registration flow
                        var newFields: [String: Any] = ["email": email]
                        if !fullNameFinal.isEmpty {
                            newFields["name"] = fullNameFinal
                        }
                        newFields["firstName"] = givenNameFinal
                        newFields["lastName"] = familyNameFinal
                        userRef.setData(newFields, merge: true)
                        DispatchQueue.main.async {
                            navigateToRegister = true
                        }
                        return
                    }
                    // Optional: update fields & FCM token
                    var fieldsToUpdate: [String: Any] = [
                        "email": email,
                        "name": fullNameFinal
                    ]
                    if !givenNameFinal.isEmpty {
                        fieldsToUpdate["firstName"] = givenNameFinal
                    }
                    if !familyNameFinal.isEmpty {
                        fieldsToUpdate["lastName"] = familyNameFinal
                    }
                    userRef.setData(fieldsToUpdate, merge: true)
                    updateFCMToken()
                }
            }
        }
    }
    
    // MARK: - Phone Sign In (unchanged)
    private func performPhoneSignIn() {
        authVM.isSignedIn = true
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let userRef = Firestore.firestore().collection("users").document(uid)
        userRef.getDocument { snapshot, _ in
            var fieldsToUpdate: [String: Any] = [
                "isAdmin": false,
                "points": 0
            ]
            if let phone = user.phoneNumber {
                fieldsToUpdate["phoneNumber"] = phone
            }
            userRef.setData(fieldsToUpdate, merge: true)
            updateFCMToken()
        }
    }

    // MARK: - Apple Sign In
    private func performAppleSignIn() {
        appleCoordinator = AppleSignInCoordinator(authVM: authVM, errorMessage: $errorMessage)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = appleCoordinator
        controller.presentationContextProvider = appleCoordinator
        controller.performRequests()
    }
}

// Notification name helper for coordinating registration navigation
extension Notification.Name {
    static let navigateToRegister = Notification.Name("navigateToRegister")
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(AuthViewModel())
    }
}
