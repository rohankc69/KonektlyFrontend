//
//  Models.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation
import CoreLocation

// MARK: - User Role
enum UserRole: String, Codable {
    case business
    case worker
}

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: UUID
    let name: String
    let email: String
    let role: UserRole
    let avatarName: String // SF Symbol or asset name
    let rating: Double
    let completedShifts: Int
    let isVerified: Bool
    let bio: String
    let skills: [String]
    let hourlyRate: Double?
    
    init(id: UUID = UUID(), name: String, email: String, role: UserRole, avatarName: String = "person.circle.fill", rating: Double, completedShifts: Int, isVerified: Bool = false, bio: String = "", skills: [String] = [], hourlyRate: Double? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.avatarName = avatarName
        self.rating = rating
        self.completedShifts = completedShifts
        self.isVerified = isVerified
        self.bio = bio
        self.skills = skills
        self.hourlyRate = hourlyRate
    }
}

// MARK: - Shift Model
struct Shift: Identifiable, Codable {
    let id: UUID
    let businessName: String
    let jobTitle: String
    let description: String
    let hourlyRate: Double
    let startTime: Date
    let endTime: Date
    let location: Location
    let requiredSkills: [String]
    let businessRating: Double
    let isUrgent: Bool
    
    var duration: String {
        let hours = Calendar.current.dateComponents([.hour], from: startTime, to: endTime).hour ?? 0
        return "\(hours)h"
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    init(id: UUID = UUID(), businessName: String, jobTitle: String, description: String, hourlyRate: Double, startTime: Date, endTime: Date, location: Location, requiredSkills: [String] = [], businessRating: Double = 5.0, isUrgent: Bool = false) {
        self.id = id
        self.businessName = businessName
        self.jobTitle = jobTitle
        self.description = description
        self.hourlyRate = hourlyRate
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.requiredSkills = requiredSkills
        self.businessRating = businessRating
        self.isUrgent = isUrgent
    }
}

// MARK: - Location Model
struct Location: Codable {
    let latitude: Double
    let longitude: Double
    let address: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, address: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
}

// MARK: - Worker Model
struct Worker: Identifiable, Codable {
    let id: UUID
    let name: String
    let avatarName: String
    let rating: Double
    let hourlyRate: Double
    let skills: [String]
    let location: Location
    let isAvailable: Bool
    let completedShifts: Int
    let responseTime: String
    let isVerified: Bool
    
    init(id: UUID = UUID(), name: String, avatarName: String = "person.circle.fill", rating: Double, hourlyRate: Double, skills: [String], location: Location, isAvailable: Bool = true, completedShifts: Int, responseTime: String = "~5 min", isVerified: Bool = false) {
        self.id = id
        self.name = name
        self.avatarName = avatarName
        self.rating = rating
        self.hourlyRate = hourlyRate
        self.skills = skills
        self.location = location
        self.isAvailable = isAvailable
        self.completedShifts = completedShifts
        self.responseTime = responseTime
        self.isVerified = isVerified
    }
}

// MARK: - Message Model
struct Message: Identifiable, Codable {
    let id: UUID
    let senderId: UUID
    let senderName: String
    let text: String
    let timestamp: Date
    let isRead: Bool
    
    init(id: UUID = UUID(), senderId: UUID, senderName: String, text: String, timestamp: Date, isRead: Bool = false) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

// MARK: - Conversation Model
struct Conversation: Identifiable {
    let id: UUID
    let otherUser: User
    let lastMessage: Message
    let unreadCount: Int
    
    init(id: UUID = UUID(), otherUser: User, lastMessage: Message, unreadCount: Int = 0) {
        self.id = id
        self.otherUser = otherUser
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
    }
}

// MARK: - Shift Status
enum ShiftStatus: String {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
}
