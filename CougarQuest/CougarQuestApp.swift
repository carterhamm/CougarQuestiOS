//
//  CougarQuestApp.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/23/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FirebaseMessaging
import FirebaseFirestore
import UIKit
import UserNotifications

// MARK: - URLSession Environment Key
private struct URLSessionKey: EnvironmentKey {
    static let defaultValue: URLSession = URLSession.shared
}

extension EnvironmentValues {
    var urlSession: URLSession {
        get { self[URLSessionKey.self] }
        set { self[URLSessionKey.self] = newValue }
    }
}

// Colors
let moonGray = Color(hue: 0.0, saturation: 0.0, brightness: 0.91)
let WagePurple = Color(hue: 281, saturation: 30, brightness: 10)
let defaultGray = Color(hue: 240, saturation: 0.24, brightness: 0.96)
let darkGray = Color(hue: 240, saturation: 0.03, brightness: 0.11)
let appleLightGray = Color(red: 0.9504, green: 0.9504, blue: 0.9696)

extension Color {
    /// Cougar Blue — PMS 293 C / HEX #0047BA
    static let cougarBlue = Color(
        red:   0   / 255,
        green: 61  / 255,
        blue:  165 / 255
    )
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase first
        FirebaseApp.configure()
        
        // Set up notifications
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        // Set FCM delegate
        Messaging.messaging().delegate = self
        
        // Configure Auth settings for phone auth
        Auth.auth().settings?.isAppVerificationDisabledForTesting = false
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle background notifications
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.newData)
    }
    
    // Handle URLs for auth flows
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }
    
    // FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("Firebase registration token: \(token)")
        // Update Firestore with new token for signed-in user
        if let uid = Auth.auth().currentUser?.uid {
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(["fcmToken": token]) { error in
                    if let error = error {
                        print("❌ Failed to update FCM token in Firestore:", error.localizedDescription)
                    } else {
                        print("✅ FCM token updated for user: \(uid)")
                    }
                }
        }
    }
}

@main
struct CougarQuestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM: AuthViewModel
    @StateObject private var profileVM: ProfileViewModel
    private let urlSession: URLSession
    @State private var sharedModelContainer: ModelContainer
    
    init() {
        // 1. Configure Firebase (now handled in AppDelegate)
        
        // 2. Initialize AuthViewModel after Firebase is ready
        _authVM = StateObject(wrappedValue: AuthViewModel())
        
        // Configure URLCache for image caching
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 500 * 1024 * 1024
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "imageCache")
        URLCache.shared = cache
        
        // Configure URLSession
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .returnCacheDataElseLoad
        sessionConfig.urlCache = cache
        self.urlSession = URLSession(configuration: sessionConfig)
        
        // Initialize ProfileViewModel
        _profileVM = StateObject(wrappedValue: ProfileViewModel())
        
        // Initialize SwiftData container
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [config])
        _sharedModelContainer = State(initialValue: container)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isSignedIn {
                    ContentView()
                } else {
                    SignInView()
                }
            }
            .modelContainer(sharedModelContainer)
            .environmentObject(authVM)
            .environment(\.urlSession, urlSession)
            .environmentObject(profileVM)
            .onChange(of: authVM.isSignedIn) { isSignedIn in
                if !isSignedIn {
                    let schema = Schema([Item.self])
                    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                    sharedModelContainer = try! ModelContainer(for: schema, configurations: [config])
                }
            }
            // Universal Link handling: cougarquest.com/quest/<id>
            .onOpenURL { url in
                print("🔗 onOpenURL: \(url.absoluteString)")
                DeepLinkState.shared.handle(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                print("🔗 onContinueUserActivity webpageURL: \(activity.webpageURL?.absoluteString ?? "nil")")
                if let url = activity.webpageURL {
                    DeepLinkState.shared.handle(url)
                }
            }
        }
    }
}
