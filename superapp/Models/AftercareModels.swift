//
//  AftercareModels.swift
//  superapp
//
//  Created by Youness Haji on 2025-09-20.
//  Updated: 2025-10-21 - Aligned with web app structure
//

import Foundation

// MARK: - Aftercare Status

enum AftercareStatus: String, Codable, CaseIterable {
    case active
    case completed
    case archived
    
    var displayTitle: String {
        switch self {
        case .active: return NSLocalizedString("Active", comment: "Aftercare status")
        case .completed: return NSLocalizedString("Completed", comment: "Aftercare status")
        case .archived: return NSLocalizedString("Archived", comment: "Aftercare status")
        }
    }
}

// MARK: - Aftercare Instruction

struct AftercareInstruction: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var day: Int
    var instruction: String
    var completed: Bool = false
    
    static func ==(lhs: AftercareInstruction, rhs: AftercareInstruction) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Aftercare Plan (Main Model - matches web app)

struct Aftercare: Identifiable, Codable, Equatable {
    var id: String
    var artistUid: String
    var artistName: String
    var clientUid: String
    var clientName: String
    var tattooDescription: String?
    var instructions: [AftercareInstruction]
    var status: AftercareStatus
    var createdAt: TimeInterval
    var updatedAt: TimeInterval
    var completedDays: [String: TimeInterval]?  // Map of day number to completion timestamp
    
    // Computed properties
    var progress: Double {
        guard !instructions.isEmpty else { return 0 }
        let completedCount = instructions.filter { $0.completed }.count
        return Double(completedCount) / Double(instructions.count)
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var isComplete: Bool {
        status == .completed || instructions.allSatisfy { $0.completed }
    }
    
    static func ==(lhs: Aftercare, rhs: Aftercare) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Legacy Models (for backward compatibility)

struct AftercareStep: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var dayOffset: Int
    var title: String
    var body: String?
    var icon: String?
}

struct AftercareTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var createdAt: TimeInterval
    var steps: [AftercareStep]
}

struct AftercarePlan: Identifiable, Codable, Equatable {
    var id: String
    var artistUid: String
    var templateName: String
    var clientUid: String
    var startDate: TimeInterval
    var steps: [AftercareStep]
    var completed: [String: TimeInterval]?
    
    var start: Date { Date(timeIntervalSince1970: startDate) }
    var end: Date {
        let last = steps.map { $0.dayOffset }.max() ?? 0
        return Calendar.current.date(byAdding: .day, value: last, to: start) ?? start
    }
    func isDone(offset: Int) -> Bool {
        completed?["\(offset)"] != nil
    }
}
