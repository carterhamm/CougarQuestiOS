//
//  NotificationService.swift
//  CougarQuest
//
//  Created by Carter Hammond on 5/13/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Service for broadcasting notifications to signed-in users via FCM.
class NotificationService {
    static let shared = NotificationService()
    private let firestore = Firestore.firestore()
    private let auth = Auth.auth()
    
    /// Your FCM server key (for legacy HTTP API). Replace with a secure retrieval method.
    private let serverKey = "YOUR_SERVER_KEY_HERE"
    
    private init() {}
    
    /// Sends a notification with the given title and body to all users who have an FCM token stored (i.e., signed-in users).
    func sendNotificationToSignedInUsers(title: String, body: String) {
        // 1) Fetch all user documents with a non-empty fcmToken
        firestore.collection("users")
            .whereField("fcmToken", isNotEqualTo: "")
            .getDocuments { snapshot, error in
                if error != nil { return }

                let tokens = snapshot?.documents.compactMap { doc in
                    doc.data()["fcmToken"] as? String
                } ?? []

                guard !tokens.isEmpty else { return }

                // 2) Build FCM payload
                let payload: [String: Any] = [
                    "registration_ids": tokens,
                    "notification": [
                        "title": title,
                        "body": body
                    ]
                ]

                // 3) Send HTTP request to FCM legacy endpoint
                guard let url = URL(string: "https://fcm.googleapis.com/fcm/send") else { return }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("key=\(self.serverKey)", forHTTPHeaderField: "Authorization")

                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
                } catch {
                    return
                }

                URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
            }
    }
}
