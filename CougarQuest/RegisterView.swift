//
//  RegisterView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 5/1/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

struct RegisterView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var profileVM: ProfileViewModel

    let skipPhoneStep: Bool
    @State private var currentStep: Step
    @State private var phoneNumber: String = ""
    @State private var verificationID: String?
    @State private var otpCode: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var sons: [String] = [""]
    @State private var errorMessage: String?
    @State private var phoneCredential: AuthCredential?
    @FocusState private var focusStep: Step?

    private let maxSons = 12

    enum Step: Int {
        case phone = 1, otp, firstName, lastName, sons
    }

    init(skipPhoneStep: Bool = false) {
        self.skipPhoneStep = skipPhoneStep
        _currentStep = State(initialValue: skipPhoneStep ? .firstName : .phone)
    }

    private func requestNotificationPermissions() {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
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
            VStack {
                Spacer()
                content
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Register")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // On the first step (phone, or firstName when phone
                        // is skipped) the back button dismisses the entire
                        // Register flow — previously it was disabled there,
                        // leaving Cancel as the only escape.
                        if currentStep.rawValue <= (skipPhoneStep ? Step.firstName.rawValue : Step.phone.rawValue) {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            previousStep()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Cancel")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            focusStep = skipPhoneStep ? .firstName : .phone
            requestNotificationPermissions()
        }
        .onChange(of: currentStep) { focusStep = currentStep }
        .navigationBarBackButtonHidden(true)
        .accentColor(.cougarBlue)
    }

    @ViewBuilder
    private var content: some View {
        switch currentStep {
        case .phone:
            phoneEntryView
        case .otp:
            otpEntryView
        case .firstName:
            nameEntryView(title: "First Name", text: $firstName) {
                currentStep = .lastName
            }
            .focused($focusStep, equals: .firstName)
        case .lastName:
            nameEntryView(title: "Last Name", text: $lastName) {
                currentStep = .sons
            }
            .focused($focusStep, equals: .lastName)
        case .sons:
            sonsEntryView
        }
    }

    private var phoneEntryView: some View {
        VStack(spacing: 20) {
            TextField("", text: $phoneNumber, prompt: Text("Phone number").foregroundColor(Color.gray.opacity(0.7)))
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.primary)
                .keyboardType(.numberPad)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .onChange(of: phoneNumber) { new in
                    phoneNumber = profileVM.formatPhone(new)
                }
                .focused($focusStep, equals: .phone)
                .submitLabel(.next)
                .onSubmit { sendOTP() }
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                sendOTP()
            }) {
                Text("Send Code")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .adaptiveGlassEffectTinted(color: Color.cougarBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(phoneNumber.filter { $0.isNumber }.count < 10)
        }
    }

    @ViewBuilder
    private var otpEntryView: some View {
        VStack(spacing: 20) {
            TextField("", text: $otpCode, prompt: Text("Code").foregroundColor(Color.gray.opacity(0.7)))
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.primary)
                .keyboardType(.numberPad)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .focused($focusStep, equals: .otp)
                .submitLabel(.next)
                .onSubmit { verifyOTP() }
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                verifyOTP()
            }) {
                Text("Verify Code")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .adaptiveGlassEffectTinted(color: Color.cougarBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(otpCode.count < 6)
        }
    }

    private func nameEntryView(title: String, text: Binding<String>, action: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            TextField("", text: text, prompt: Text(title).foregroundColor(Color.gray.opacity(0.7)))
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.primary)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .submitLabel(.next)
                .onSubmit {
                    if !text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        action()
                    }
                }
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                action()
            }) {
                Text("Continue")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .adaptiveGlassEffectTinted(color: Color.cougarBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var sonsEntryView: some View {
        VStack(spacing: 20) {
            ForEach(sons.indices, id: \.self) { idx in
                HStack {
                    // For the first TextField, add .focused and remove font(.system(size: 30, weight: .bold))
                    Group {
                        if idx == 0 {
                            TextField("", text: $sons[idx], prompt: Text("Son \(idx+1) Name").foregroundColor(Color.gray.opacity(0.7)))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .focused($focusStep, equals: .sons)
                        } else {
                            TextField("", text: $sons[idx], prompt: Text("Son \(idx + 1) Name")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color.gray.opacity(0.7)))
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                        }
                    }
                    if sons.count > 1 {
                        Button {
                            sons.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            if sons.count < maxSons {
                Button {
                    sons.append("")
                } label: {
                    Label("Add Son", systemImage: "plus.circle")
                }
            }
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                finalizeRegistration()
            }) {
                Text("Register")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .adaptiveGlassEffectTinted(color: Color.cougarBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(sons.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.isEmpty)
        }
    }

    private func sendOTP() {
        errorMessage = nil
        let digits = phoneNumber.filter { $0.isNumber }
        guard digits.count == 10 else {
            errorMessage = "Please enter a valid 10‑digit phone number."
            return
        }
        let fullPhone = "+1" + digits
        #if targetEnvironment(simulator)
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        PhoneAuthProvider.provider().verifyPhoneNumber(fullPhone, uiDelegate: nil) { id, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    verificationID = id
                    currentStep = .otp
                }
            }
        }
    }

    private func verifyOTP() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        guard let id = verificationID else { return }
        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: id, verificationCode: otpCode.trimmingCharacters(in: .whitespaces))
        Auth.auth().signIn(with: credential) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                } else if let user = result?.user {
                    let userRef = Firestore.firestore().collection("users").document(user.uid)
                    userRef.getDocument { snapshot, _ in
                        if let snapshot = snapshot, snapshot.exists {
                            // Existing account: sign in complete
                            authVM.isSignedIn = true
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            // New user: proceed to collect name
                            phoneCredential = credential
                            currentStep = .firstName
                        }
                    }
                }
            }
        }
    }

    private func finalizeRegistration() {
        errorMessage = nil
        // Assign profile fields for phone sign-up only
        if !skipPhoneStep {
            profileVM.name = "\(firstName) \(lastName)"
            profileVM.firstName = firstName
            profileVM.lastName = lastName
            profileVM.rawPhone = phoneNumber
        }
        profileVM.sons = sons.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        func saveProfile() {
            profileVM.save { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    updateFCMToken()
                    authVM.isSignedIn = true
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        if let credential = phoneCredential {
            Auth.auth().signIn(with: credential) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else {
                        saveProfile()
                    }
                }
            }
        } else {
            saveProfile()
        }
    }

    private func previousStep() {
        errorMessage = nil
        let previousRaw = currentStep.rawValue - 1
        if let previous = Step(rawValue: previousRaw) {
            currentStep = previous
        }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(AuthViewModel())
            .environmentObject(ProfileViewModel())
    }
}
