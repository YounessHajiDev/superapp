//
//  UserProfile.swift
//  InkMatching
//
//  Created by You on 2025-09-08.
//

import Foundation

// MARK: - Role

enum UserRole: String, Codable, CaseIterable, Hashable {
    case client
    case artist

    var displayTitle: String {
        switch self {
        case .client: return NSLocalizedString("Client", comment: "User role")
        case .artist: return NSLocalizedString("Artist", comment: "User role")
        }
    }

    var systemSymbol: String {
        switch self {
        case .client: return "person"
        case .artist: return "paintbrush.pointed"
        }
    }
}

// MARK: - User Profile

struct UserProfile: Identifiable, Codable, Hashable {
    // Firebase UID doubles as the SwiftUI .id
    var id: String { uid }

    // Core
    let uid: String
    var email: String?
    var displayName: String
    var photoURL: String?
    var role: UserRole

    // Timestamps (seconds since 1970)
    var createdAt: TimeInterval?
    var updatedAt: TimeInterval?

    // MARK: - Computed

    var displayInitials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first?.uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }

    // MARK: - Init

    init(uid: String,
         email: String? = nil,
         displayName: String,
         photoURL: String? = nil,
         role: UserRole,
         createdAt: TimeInterval? = Date().timeIntervalSince1970,
         updatedAt: TimeInterval? = Date().timeIntervalSince1970) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Firebase (Dictionary) helpers

extension UserProfile {
    /// Minimal public map you can store under `/users/{uid}` in Realtime Database.
    /// Keep only non-sensitive fields that other users may read (name/photo/role).
    var toPublicMap: [String: Any] {
        var map: [String: Any] = [
            "uid": uid,
            "displayName": displayName,
            "role": role.rawValue
        ]
        if let photoURL { map["photoURL"] = photoURL }
        if let email { map["email"] = email } // include if you show it in UI; remove if private
        if let createdAt { map["createdAt"] = createdAt }
        if let updatedAt { map["updatedAt"] = updatedAt }
        return map
    }

    /// Initialize from a Firebase dictionary (e.g., snapshot.value as? [String: Any]).
    static func from(_ dict: [String: Any], fallbackUID: String) -> UserProfile? {
        let uid = (dict["uid"] as? String) ?? fallbackUID
        guard let name = dict["displayName"] as? String else { return nil }
        let roleStr = (dict["role"] as? String) ?? "client"
        let email = dict["email"] as? String
        let photo = dict["photoURL"] as? String
        let created = dict["createdAt"] as? TimeInterval
        let updated = dict["updatedAt"] as? TimeInterval

        guard let role = UserRole(rawValue: roleStr) else { return nil }
        return UserProfile(uid: uid,
                           email: email,
                           displayName: name,
                           photoURL: photo,
                           role: role,
                           createdAt: created,
                           updatedAt: updated)
    }
}

// MARK: - Mocks (useful in previews)

extension UserProfile {
    static let mockClient = UserProfile(uid: "u_client_1",
                                        email: "client@example.com",
                                        displayName: "Alex Client",
                                        photoURL: nil,
                                        role: .client)

    static let mockArtist = UserProfile(uid: "u_artist_1",
                                        email: "artist@example.com",
                                        displayName: "Bella Ink",
                                        photoURL: nil,
                                        role: .artist)
}
