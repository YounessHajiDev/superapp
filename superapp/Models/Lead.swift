//
//  Lead.swift
//  superapp
//
//  Created by Youness Haji on 2025-09-19.
//

import Foundation

enum LeadStatus: String, Codable, CaseIterable {
    case new, accepted, declined, archived
}

struct Lead: Identifiable, Codable, Equatable {
    var id: String
    var clientId: String
    var clientName: String
    var message: String?
    var style: String?
    var city: String?
    var createdAt: TimeInterval
    var status: LeadStatus
    
    // Management fields
    var internalNote: String?
    var quotedPrice: Double?
    var currency: String?
    var updatedAt: TimeInterval?
    
    // NEW: Link to aftercare plan
    var aftercareId: String?

    static func ==(lhs: Lead, rhs: Lead) -> Bool { lhs.id == rhs.id }
}
