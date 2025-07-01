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
                if let error = error {
                    print("❌ Error fetching users for notification:", error.localizedDescription)
                    return
                }
                
                let tokens = snapshot?.documents.compactMap { doc in
                    doc.data()["fcmToken"] as? String
                } ?? []
                
                guard !tokens.isEmpty else {
                    print("ℹ️ No FCM tokens found, skipping notification.")
                    return
                }
                
                // 2) Build FCM payload
                let payload: [String: Any] = [
                    "registration_ids": tokens,
                    "notification": [
                        "title": title,
                        "body": body
                    ]
                ]
                
                // 3) Send HTTP request to FCM legacy endpoint
                guard let url = URL(string: "https://fcm.googleapis.com/fcm/send") else {
                    print("❌ Invalid FCM URL.")
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("key=\(self.serverKey)", forHTTPHeaderField: "Authorization")
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
                } catch {
                    print("❌ Failed to encode FCM payload:", error.localizedDescription)
                    return
                }
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("❌ Notification send error:", error.localizedDescription)
                        return
                    }
                    if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                        print("❌ FCM responded with status code:", httpResp.statusCode)
                    } else {
                        print("✅ Notification sent to \(tokens.count) users.")
                    }
                }
                task.resume()
            }
    }
}
