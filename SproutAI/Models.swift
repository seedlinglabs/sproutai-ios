//
//  Models.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import Foundation

// MARK: - Authentication Models
struct Parent: Codable {
    let userId: String
    let email: String?
    let name: String
    let userType: String
    let classAccess: [String]
    let schoolId: String
    let phoneNumber: String?
    let isActive: Bool?
    let createdAt: String?
    let lastLogin: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case name
        case userType = "user_type"
        case classAccess = "class_access"
        case schoolId = "school_id"
        case phoneNumber = "phone_number"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }
}

struct LoginRequest: Codable {
    let phoneNumber: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case name
    }
}

struct AuthResponse: Codable {
    let success: Bool?
    let user: Parent
    let token: String
    let message: String
}

struct APIErrorResponse: Codable {
    let error: String
}

enum AuthState {
    case checking, unauthenticated, authenticated
}

// MARK: - Academic Data Models
struct SproutTopic: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let subjectId: String
    let schoolId: String
    let classId: String
    let createdAt: String
    let updatedAt: String
    let aiContent: SproutAIContent?
}

struct SproutTopicWithCompletion: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let subjectId: String
    let schoolId: String
    let classId: String
    let createdAt: String
    let updatedAt: String
    let aiContent: SproutAIContent?
    let completedAt: String?
}

struct SproutAIContent: Codable {
    let summary: String?
    let videos: [SproutVideo]?
    let assessmentQuestions: String?
}

struct SproutVideo: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let duration: String?
    let thumbnail: String?
    
    init(id: String = UUID().uuidString, title: String, url: String, duration: String? = nil, thumbnail: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.duration = duration
        self.thumbnail = thumbnail
    }
}

struct SproutSubjectWithProgress: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let classId: String
    let schoolId: String
    let schoolName: String?
    let className: String?
    let createdAt: String
    let updatedAt: String
    let totalTopics: Int?
    let completedTopics: Int?
    let completedTopicsList: [SproutTopicWithCompletion]?
}

struct SproutAcademicRecord: Codable {
    let id: String
    let userId: String
    let subjectId: String
    let subjectName: String
    let topicId: String
    let topicName: String
    let grade: String
    let section: String
    let status: String // "completed", "in_progress", etc.
    let score: Double?
    let createdAt: String
    let updatedAt: String
}

// MARK: - Quiz Models
struct QuizQuestion: Identifiable, Codable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctAnswer: Int
    let explanation: String?
}

struct QuizResult: Identifiable {
    let id = UUID()
    let questionId: UUID
    let selectedAnswer: Int
    let isCorrect: Bool
    let timeSpent: TimeInterval?
}

// Supporting JSON structures for quiz parsing
struct QuizQuestionJSON: Codable {
    let question: String
    let options: [String]
    let correctAnswer: Int
    let explanation: String?
    
    func toQuizQuestion() -> QuizQuestion {
        QuizQuestion(
            question: question,
            options: options,
            correctAnswer: correctAnswer,
            explanation: explanation
        )
    }
}

struct QuizWrapper: Codable {
    let questions: [QuizQuestionJSON]
}