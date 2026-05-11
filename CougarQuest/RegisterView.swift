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
        case phone = 1, otp, name, sons
    }
    private enum NameField: Hashable { case first, last }
    @FocusState private var nameFocus: NameField?

    init(skipPhoneStep: Bool = false) {
        self.skipPhoneStep = skipPhoneStep
        _currentStep = State(initialValue: skipPhoneStep ? .name : .phone)
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
      Messaging.messaging().token { token, _ in
        if let token = token {
          let userRef = Firestore.firestore().collection("users").document(user.uid)
          userRef.setData(["fcmToken": token], merge: true)
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
                        if currentStep.rawValue <= (skipPhoneStep ? Step.name.rawValue : Step.phone.rawValue) {
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
            focusStep = skipPhoneStep ? .name : .phone
            if currentStep == .name { nameFocus = .first }
            requestNotificationPermissions()
        }
        .onChange(of: currentStep) {
            focusStep = currentStep
            if currentStep == .name { nameFocus = .first }
        }
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
        case .name:
            nameEntryView
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

    private var nameEntryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your name")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("So your sons see who's leading the team.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                fieldRow(label: "First name", text: $firstName, focus: .first, submit: .next) {
                    nameFocus = .last
                }
                fieldRow(label: "Last name", text: $lastName, focus: .last, submit: .done) {
                    if canContinueFromName { currentStep = .sons }
                }
            }

            Button(action: {
                let g = UIImpactFeedbackGenerator(style: .soft); g.impactOccurred()
                currentStep = .sons
            }) {
                Text("Continue")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .adaptiveGlassEffectTinted(color: Color.cougarBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canContinueFromName)
        }
    }

    private var canContinueFromName: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func fieldRow(
        label: String,
        text: Binding<String>,
        focus: NameField,
        submit: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundColor(.secondary))
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.primary)
            .textContentType(focus == .first ? .givenName : .familyName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cougarBlue.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        nameFocus == focus
                            ? Color.cougarBlue.opacity(0.55)
                            : Color.cougarBlue.opacity(0.18),
                        lineWidth: nameFocus == focus ? 1.5 : 1
                    )
            )
            .focused($nameFocus, equals: focus)
            .submitLabel(submit)
            .onSubmit(onSubmit)
    }

    private var sonsEntryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your team")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Add the sons coming with you. You can edit this later.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(sons.indices, id: \.self) { idx in
                    sonRow(idx: idx)
                }

                if sons.count < maxSons {
                    Button {
                        let g = UIImpactFeedbackGenerator(style: .light); g.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            sons.append("")
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusStep = .sons
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Add another son")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.cougarBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    Color.cougarBlue.opacity(0.45),
                                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: {
                let g = UIImpactFeedbackGenerator(style: .soft); g.impactOccurred()
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
            .disabled(sons.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        }
    }

    private func sonRow(idx: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(idx + 1)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.cougarBlue)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(Color.cougarBlue.opacity(0.14))
                )

            TextField("", text: $sons[idx], prompt: Text("Son's name").foregroundColor(.secondary))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusStep, equals: idx == 0 ? .sons : nil)

            if sons.count > 1 {
                Button {
                    let g = UIImpactFeedbackGenerator(style: .light); g.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        sons.remove(at: idx)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.secondary.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cougarBlue.opacity(0.06))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.cougarBlue.opacity(0.18), lineWidth: 1)
        )
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
                            currentStep = .name
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
