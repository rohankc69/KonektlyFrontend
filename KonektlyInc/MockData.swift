//
//  MockData.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation

struct MockData {
    
    // MARK: - Current User
    static let currentUser = User(
        name: "Alex Johnson",
        email: "alex@example.com",
        role: .worker,
        rating: 4.8,
        completedShifts: 47,
        isVerified: true,
        bio: "Experienced hospitality professional with 5+ years in customer service.",
        skills: ["Customer Service", "Cash Handling", "Food Service"],
        hourlyRate: 25.0
    )
    
    // MARK: - Sample Users
    static let users: [User] = [
        User(name: "Sarah Chen", email: "sarah@business.com", role: .business, rating: 4.9, completedShifts: 120, isVerified: true, bio: "Restaurant owner", skills: []),
        User(name: "Mike Rodriguez", email: "mike@worker.com", role: .worker, rating: 4.7, completedShifts: 89, isVerified: true, bio: "Professional server", skills: ["Bartending", "Fine Dining"], hourlyRate: 28.0),
        User(name: "Emma Davis", email: "emma@worker.com", role: .worker, rating: 4.9, completedShifts: 156, isVerified: true, bio: "Event specialist", skills: ["Event Management", "Customer Service"], hourlyRate: 30.0),
        User(name: "James Wilson", email: "james@business.com", role: .business, rating: 4.6, completedShifts: 78, isVerified: true, bio: "Cafe manager", skills: [])
    ]
    
    // MARK: - Sample Locations (San Francisco area)
    static let locations: [Location] = [
        Location(latitude: 37.7749, longitude: -122.4194, address: "123 Market St, San Francisco, CA"),
        Location(latitude: 37.7849, longitude: -122.4094, address: "456 Mission St, San Francisco, CA"),
        Location(latitude: 37.7649, longitude: -122.4294, address: "789 Valencia St, San Francisco, CA"),
        Location(latitude: 37.7949, longitude: -122.3994, address: "321 Folsom St, San Francisco, CA"),
        Location(latitude: 37.7549, longitude: -122.4394, address: "654 Hayes St, San Francisco, CA"),
    ]
    
    // MARK: - Sample Shifts
    static let shifts: [Shift] = [
        Shift(
            businessName: "The Golden Bistro",
            jobTitle: "Server",
            description: "Busy lunch shift, experience with POS systems preferred. High-volume restaurant.",
            hourlyRate: 25.0,
            startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
            endTime: Calendar.current.date(byAdding: .hour, value: 7, to: Date())!,
            location: locations[0],
            requiredSkills: ["Customer Service", "Food Service"],
            businessRating: 4.8,
            isUrgent: true
        ),
        Shift(
            businessName: "Brew & Co.",
            jobTitle: "Barista",
            description: "Morning coffee rush coverage. Latte art skills a plus!",
            hourlyRate: 22.0,
            startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            endTime: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!)!,
            location: locations[1],
            requiredSkills: ["Barista", "Cash Handling"],
            businessRating: 4.9,
            isUrgent: false
        ),
        Shift(
            businessName: "Events Plus",
            jobTitle: "Event Staff",
            description: "Corporate event setup and guest services. Must be professional and punctual.",
            hourlyRate: 28.0,
            startTime: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            endTime: Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.date(byAdding: .hour, value: 6, to: Date())!)!,
            location: locations[2],
            requiredSkills: ["Event Management", "Customer Service"],
            businessRating: 4.7,
            isUrgent: false
        ),
        Shift(
            businessName: "Marina Grill",
            jobTitle: "Host/Hostess",
            description: "Weekend dinner service. Welcoming personality required.",
            hourlyRate: 20.0,
            startTime: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            endTime: Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.date(byAdding: .hour, value: 5, to: Date())!)!,
            location: locations[3],
            requiredSkills: ["Customer Service"],
            businessRating: 4.6,
            isUrgent: false
        ),
        Shift(
            businessName: "City Bar",
            jobTitle: "Bartender",
            description: "Evening shift, mixology skills preferred. TIPS certified required.",
            hourlyRate: 30.0,
            startTime: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
            endTime: Calendar.current.date(byAdding: .hour, value: 10, to: Date())!,
            location: locations[4],
            requiredSkills: ["Bartending", "Cash Handling"],
            businessRating: 4.5,
            isUrgent: true
        )
    ]
    
    // MARK: - Sample Workers
    static let workers: [Worker] = [
        Worker(
            name: "Emily Santos",
            rating: 4.9,
            hourlyRate: 28.0,
            skills: ["Bartending", "Customer Service", "Food Service"],
            location: locations[0],
            isAvailable: true,
            completedShifts: 134,
            responseTime: "~3 min",
            isVerified: true
        ),
        Worker(
            name: "Jordan Lee",
            rating: 4.7,
            hourlyRate: 25.0,
            skills: ["Customer Service", "Cash Handling"],
            location: locations[1],
            isAvailable: true,
            completedShifts: 89,
            responseTime: "~5 min",
            isVerified: true
        ),
        Worker(
            name: "Taylor Morgan",
            rating: 4.8,
            hourlyRate: 30.0,
            skills: ["Event Management", "Fine Dining", "Customer Service"],
            location: locations[2],
            isAvailable: true,
            completedShifts: 203,
            responseTime: "~2 min",
            isVerified: true
        ),
        Worker(
            name: "Alex Kim",
            rating: 4.6,
            hourlyRate: 22.0,
            skills: ["Barista", "Food Service"],
            location: locations[3],
            isAvailable: false,
            completedShifts: 56,
            responseTime: "~10 min",
            isVerified: false
        ),
        Worker(
            name: "Sam Patel",
            rating: 4.9,
            hourlyRate: 32.0,
            skills: ["Bartending", "Fine Dining", "Event Management"],
            location: locations[4],
            isAvailable: true,
            completedShifts: 287,
            responseTime: "~1 min",
            isVerified: true
        )
    ]
    
    // MARK: - Sample Messages
    static func sampleMessages(for conversationId: UUID) -> [Message] {
        let now = Date()
        return [
            Message(
                senderId: users[0].id,
                senderName: users[0].name,
                text: "Hi! Are you available for the shift tomorrow?",
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: now)!,
                isRead: true
            ),
            Message(
                senderId: currentUser.id,
                senderName: currentUser.name,
                text: "Yes, I can make it! What time should I arrive?",
                timestamp: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
                isRead: true
            ),
            Message(
                senderId: users[0].id,
                senderName: users[0].name,
                text: "Perfect! Please arrive 15 minutes early for briefing. See you then!",
                timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: now)!,
                isRead: true
            ),
            Message(
                senderId: currentUser.id,
                senderName: currentUser.name,
                text: "Sounds good, thank you!",
                timestamp: Calendar.current.date(byAdding: .minute, value: -25, to: now)!,
                isRead: true
            )
        ]
    }
    
    // MARK: - Sample Conversations
    static let conversations: [Conversation] = [
        Conversation(
            otherUser: users[0],
            lastMessage: Message(
                senderId: users[0].id,
                senderName: users[0].name,
                text: "Perfect! Please arrive 15 minutes early for briefing.",
                timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!,
                isRead: true
            ),
            unreadCount: 0
        ),
        Conversation(
            otherUser: users[1],
            lastMessage: Message(
                senderId: users[1].id,
                senderName: users[1].name,
                text: "Great work today! Thanks for filling in.",
                timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!,
                isRead: true
            ),
            unreadCount: 0
        ),
        Conversation(
            otherUser: users[2],
            lastMessage: Message(
                senderId: users[2].id,
                senderName: users[2].name,
                text: "Would you be interested in another shift next week?",
                timestamp: Calendar.current.date(byAdding: .minute, value: -15, to: Date())!,
                isRead: false
            ),
            unreadCount: 2
        )
    ]
}
