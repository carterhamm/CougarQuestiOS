//
//  Models.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/27/25.
//

import SwiftUI
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine
import FirebaseMessaging

class FirebaseService {
  static let shared = FirebaseService()
  private let db = Firestore.firestore()
  private let storage = Storage.storage(url: "gs://cougarquest-62ba2.firebasestorage.app")

  // Automatically create or update the Firestore user doc on Google Sign-In
  private init() {
    // Enable offline persistence for Firestore
    let settings = db.settings
    settings.isPersistenceEnabled = true
    db.settings = settings
    Auth.auth().addStateDidChangeListener { [weak self] _, user in
        guard let self = self, let user = user else { return }
        let userRef = self.db.collection("users").document(user.uid)
        
        // Only initialize completedQuests for new users
        userRef.getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists {
                // Existing user: update only mutable fields
                var updateData: [String: Any] = ["phoneNumber": user.phoneNumber ?? ""]
                if let displayName = user.displayName, !displayName.isEmpty {
                    updateData["name"] = displayName
                }
                userRef.setData(updateData, merge: true)
                
                // Fetch and save FCM token for push notifications
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("❌ FCM token error:", error.localizedDescription)
                    } else if let token = token {
                        userRef.updateData(["fcmToken": token])
                    }
                }
            } else {
                // New user: set all default fields including completedQuests
                var newData: [String: Any] = [
                    "uid": user.uid,
                    "phoneNumber": user.phoneNumber ?? "",
                    "sons": [] as [String],
                    "points": 0,
                    "completedQuests": [] as [String],
                    "isAdmin": false
                ]
                if let displayName = user.displayName, !displayName.isEmpty {
                    newData["name"] = displayName
                }
                userRef.setData(newData, merge: true) { error in
                    if let error = error {
                        print("❌ Failed to create user profile:", error.localizedDescription)
                    }
                }
                
                // Fetch and save FCM token for push notifications
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("❌ FCM token error:", error.localizedDescription)
                    } else if let token = token {
                        userRef.updateData(["fcmToken": token])
                    }
                }
            }
        }
    }
  }

  // MARK: – Add a quest (with optional photo)
  func addQuest(_ quest: Quest, photo: UIImage?, completion: @escaping (Error?) -> Void) {
    let questsRef = db.collection("quests")
    var data = try! Firestore.Encoder().encode(quest)

    // Record creation timestamp
    data["createdAt"] = FieldValue.serverTimestamp()

    // 1. Add placeholder doc to get an ID
    let doc = questsRef.document()
    data["id"] = doc.documentID

    // 2. Write initial quest document
    data["photoURL"] = ""  // placeholder
    doc.setData(data) { [weak self] error in
      guard let self = self else { return }
      if let error = error {
        completion(error)
        return
      }
      // 3. If there's a photo, upload and then update the document
      if let image = photo,
         let jpeg = image.jpegData(compressionQuality: 0.2) {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let photoRef = self.storage.reference()
          .child("questPhotos/\(doc.documentID).jpg")
        photoRef.putData(jpeg, metadata: metadata) { _, error in
          guard error == nil else { return }
          photoRef.downloadURL { url, error in
            guard let url = url else { return }
            doc.updateData(["photoURL": url.absoluteString])
          }
        }
      }
      // 4. Notify caller that the quest was created
      completion(nil)
    }
  }

  // MARK: – Fetch all quests
  func fetchQuests(completion: @escaping ([Quest]?, Error?) -> Void) {
    db.collection("quests").getDocuments { snap, err in
      guard let docs = snap?.documents else {
        completion(nil, err); return
      }
      let quests = docs.compactMap { try? $0.data(as: Quest.self) }
      completion(quests, nil)
    }
  }

  // MARK: – Create/update user profile
  func createUserProfile(_ profile: UserProfile, completion: @escaping (Error?) -> Void) {
    guard let uid = profile.id else { return }
    do {
      try db.collection("users")
        .document(uid)
        .setData(from: profile, merge: true, completion: completion)
    } catch {
      completion(error)
    }
  }
}

struct Coordinates: Codable {
  var latitude: Double
  var longitude: Double
}

struct Location: Codable {
  var address: String
  var coordinates: Coordinates
}

struct Quest: Identifiable, Codable {
  @DocumentID var id: String?        // Firestore-generated ID
  var title: String
  var address: String
  var description: String
  var mapsLink: String
  var plusCode: String
  var photoURL: String               // downloadURL from Storage
  var createdAt: Date?
  var completedAt: Date?

  private enum CodingKeys: String, CodingKey {
    case id
    case title, address, description, photoURL, createdAt, completedAt
    case mapsLink
    case plusCode
  }
}

struct UserProfile: Identifiable, Codable {
  @DocumentID var id: String?        // set to Auth.auth().currentUser!.uid
  var name: String
  var firstName: String?
  var lastName: String?
  var phoneNumber: String
  var sons: [String]
  var points: Int
  var completedQuests: [String]      // array of quest IDs
  var teamName: String?
  var grandpa: String?
}

//AuthView Model, formerly in CougarQuestApp
class AuthViewModel: ObservableObject {
  @Published var isSignedIn: Bool = false
  private var handle: AuthStateDidChangeListenerHandle?

  init() {
    // Set initial sign-in state
    isSignedIn = Auth.auth().currentUser != nil
    // Listen for auth state changes
    handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      DispatchQueue.main.async {
        self?.isSignedIn = (user != nil)
      }
    }
  }

  deinit {
    // Clean up listener
    if let h = handle {
      Auth.auth().removeStateDidChangeListener(h)
    }
  }
}

class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var rawPhone: String = ""
    @Published var sons: [String] = [""]
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var isAdmin: Bool = false
    @Published var teamName: String = ""
    @Published var grandpa: String = ""
    
    let maxSons = 8
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load cached primitive fields from UserDefaults
        self.name = UserDefaults.standard.string(forKey: "cachedUserName") ?? ""
        self.rawPhone = UserDefaults.standard.string(forKey: "cachedUserPhone") ?? ""
        let cachedSons = UserDefaults.standard.stringArray(forKey: "cachedUserSons") ?? []
        self.sons = cachedSons.isEmpty ? [""] : cachedSons
        // Begin listening for remote updates
        load()
    }
    
    func load() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        listener?.remove()
        listener = db.collection("users").document(userId).addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            DispatchQueue.main.async {
                self.name = data["name"] as? String ?? ""
                self.rawPhone = data["phoneNumber"] as? String ?? ""
                self.firstName = data["firstName"] as? String ?? ""
                self.lastName = data["lastName"] as? String ?? ""
                self.sons = data["sons"] as? [String] ?? [""]
                self.isAdmin = data["isAdmin"] as? Bool ?? false
                self.teamName = data["teamName"] as? String ?? ""
                self.grandpa = data["grandpa"] as? String ?? ""
                
                // Cache primitive fields locally
                UserDefaults.standard.set(self.name, forKey: "cachedUserName")
                UserDefaults.standard.set(self.rawPhone, forKey: "cachedUserPhone")
                UserDefaults.standard.set(self.sons, forKey: "cachedUserSons")
            }
        }
    }
    
    func save(completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "name": name,
            "firstName": firstName,
            "lastName": lastName,
            "phoneNumber": rawPhone,
            "sons": sons,
            "teamName": teamName,
            "grandpa": grandpa,
        ]
        db.collection("users").document(userId).setData(data, merge: true) { error in
            completion(error)
        }
    }
    
    func signOut(authVM: AuthViewModel) {
        do {
            // 1) Firebase sign-out
            try Auth.auth().signOut()
            
            // Clear FCM token on logout
            if let uid = Auth.auth().currentUser?.uid {
                db.collection("users").document(uid).updateData(["fcmToken": ""])
            }
            
            // 2) Clear local caches
            UserDefaults.standard.removeObject(forKey: "cachedUserName")
            UserDefaults.standard.removeObject(forKey: "cachedUserPhone")
            UserDefaults.standard.removeObject(forKey: "cachedUserSons")
            URLCache.shared.removeAllCachedResponses()
            
            // 3) Remove Firestore listener
            listener?.remove()
            
            // 4) Reset view-model properties on main thread
            DispatchQueue.main.async {
                self.name = ""
                self.rawPhone = ""
                self.sons = [""]
                self.firstName = ""
                self.lastName = ""
                self.isAdmin = false
                self.teamName = ""
                self.grandpa = ""
            }
            
            // 5) Notify auth state
            authVM.isSignedIn = false
        } catch {
            print("Sign out error: \(error.localizedDescription)")
        }
    }
    
    var isFormValid: Bool {
        !name.isEmpty && !rawPhone.isEmpty && sons.allSatisfy { !$0.isEmpty }
    }
    
    func formatPhone(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        var result = ""
        let mask = "(XXX) XXX-XXXX"
        var index = digits.startIndex
        
        for ch in mask where index < digits.endIndex {
            if ch == "X" {
                result.append(digits[index])
                index = digits.index(after: index)
            } else {
                result.append(ch)
            }
        }
        return result
    }
    
    /// Display name with fallback to teamName, son names, or “Unnamed user”
    var displayName: String {
        if !teamName.isEmpty {
            return teamName
        }
        let validSons = sons.filter { !$0.isEmpty }
        if !validSons.isEmpty {
            return validSons.joined(separator: ", ")
        }
        return "Unnamed user"
    }
}

extension FirebaseService {
  /// Deletes the quest document and its photo (optional).
  func deleteQuest(_ quest: Quest, completion: @escaping (Error?) -> Void) {
    guard let id = quest.id else {
      completion(NSError(domain: "DeleteQuest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid quest ID"]))
      return
    }

    let docRef = db.collection("quests").document(id)
    // 1) Delete Firestore document
    docRef.delete { error in
      if let error = error {
        completion(error)
        return
      }
      // 2) (Optional) Delete stored photo
      let photoRef = self.storage.reference().child("questPhotos/\(id).jpg")
      photoRef.delete { _ in
        // ignore storage errors for now
        completion(nil)
      }
    }
  }
}

final class SelectionManager: ObservableObject {
    @Published var selectedQuest: Quest? = nil
}
