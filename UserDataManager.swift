//
//  UserDataManager.swift
//  TimelyNew
//
//  Created by ilsu on 10.06.2025.
//

import Foundation
import FirebaseFirestore

// ✅ Tüm eksik property'ler eklendi
struct UserProfile: Codable, Identifiable {
    let id: String
    var firstName: String
    var lastName: String = ""
    var email: String
    var purpose: String = ""
    var schedulingPreference: String = ""
    var calendarProvider: String = ""
    var isOnboardingCompleted: Bool = false
    var createdAt: Date = Date()
    var phoneNumber: String = ""  // ← String olarak değiştirildi (optional değil)
    var avatarURL: String = ""    // ← String olarak değiştirildi (optional değil)
    
    // ✅ Computed property eklendi
    var displayName: String {
        if lastName.isEmpty {
            return firstName
        }
        return "\(firstName) \(lastName)"
    }
    
    // ✅ Custom initializer eklendi
    init(id: String, firstName: String, email: String, lastName: String = "") {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        // Diğer property'ler default değerlerini alacak
    }
    
    // ✅ Full initializer (tüm parametrelerle)
    init(id: String, firstName: String, lastName: String, email: String,
         purpose: String, schedulingPreference: String, calendarProvider: String,
         isOnboardingCompleted: Bool, createdAt: Date, phoneNumber: String, avatarURL: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.purpose = purpose
        self.schedulingPreference = schedulingPreference
        self.calendarProvider = calendarProvider
        self.isOnboardingCompleted = isOnboardingCompleted
        self.createdAt = createdAt
        self.phoneNumber = phoneNumber
        self.avatarURL = avatarURL
    }
}

class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // ✅ UserProfile kullanacak şekilde - orijinal halinde kalsın
    func saveUserProfile(_ profile: UserProfile, completion: @escaping (Bool, Error?) -> Void) {
        do {
            try db.collection("users").document(profile.id).setData(from: profile) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error)
                    } else {
                        completion(true, nil)
                    }
                }
            }
        } catch {
            completion(false, error)
        }
    }
    
    // ✅ UserProfile dönecek şekilde - orijinal halinde kalsın
    func getUserProfile(userId: String, completion: @escaping (UserProfile?, Error?) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let document = document, document.exists else {
                    completion(nil, nil)
                    return
                }
                
                do {
                    let profile = try document.data(as: UserProfile.self)
                    completion(profile, nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }
}
