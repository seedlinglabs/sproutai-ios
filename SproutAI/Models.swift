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
    let password: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case password
        case name
    }
}

struct AuthResponse: Codable {
    let success: Bool?
    let user: Parent
    let token: String
    let message: String?
}

struct APIErrorResponse: Codable {
    let error: String?
    let message: String?
    let details: String?
    
    var displayMessage: String {
        if let error = error?.trimmedNonEmpty { return error }
        if let message = message?.trimmedNonEmpty { return message }
        if let details = details?.trimmedNonEmpty { return details }
        return "Something went wrong. Please try again."
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct OTPResponse: Codable {
    let success: Bool
    let message: String
    let otpId: String?
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case otpId = "otp_id"
    }
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
    let submittedText: String? // For non-multiple choice answers
    let isCorrect: Bool
    let timeSpent: TimeInterval?
    var attemptCount: Int = 1 // Track number of attempts per question
    
    init(questionId: UUID, selectedAnswer: Int, submittedText: String? = nil, isCorrect: Bool, timeSpent: TimeInterval?, attemptCount: Int = 1) {
        self.questionId = questionId
        self.selectedAnswer = selectedAnswer
        self.submittedText = submittedText
        self.isCorrect = isCorrect
        self.timeSpent = timeSpent
        self.attemptCount = attemptCount
    }
}

// Quiz metrics for displaying per-question statistics
struct QuizMetrics {
    let totalQuestions: Int
    let correctAnswers: Int
    let incorrectAnswers: Int
    let averageTimePerQuestion: TimeInterval
    let totalTime: TimeInterval
    let scorePercentage: Double
    let passThreshold: Double = 70.0
    
    var passed: Bool {
        scorePercentage >= passThreshold
    }
    
    var status: String {
        passed ? "Passed" : "Failed"
    }
    
    init(results: [QuizResult], totalTime: TimeInterval) {
        self.totalQuestions = results.count
        self.correctAnswers = results.filter(\.isCorrect).count
        self.incorrectAnswers = totalQuestions - correctAnswers
        self.totalTime = totalTime
        self.averageTimePerQuestion = totalQuestions > 0 ? totalTime / Double(totalQuestions) : 0
        self.scorePercentage = totalQuestions > 0 ? (Double(correctAnswers) / Double(totalQuestions)) * 100 : 0
    }
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

// MARK: - Learning Assist Models
struct MarkCompleteResponse: Codable {
    let success: Bool
    let message: String
    let topicId: String
    let completedAt: String
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case topicId = "topic_id"
        case completedAt = "completed_at"
    }
}

struct LearningProgressResponse: Codable {
    let userId: String
    let totalTopics: Int
    let completedTopics: Int
    let progressPercentage: Double
    let completedTopicsList: [CompletedTopic]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalTopics = "total_topics"
        case completedTopics = "completed_topics"
        case progressPercentage = "progress_percentage"
        case completedTopicsList = "completed_topics_list"
    }
}

struct CompletedTopic: Codable {
    let topicId: String
    let topicName: String
    let subjectId: String
    let completedAt: String
    let score: Double?
    
    enum CodingKeys: String, CodingKey {
        case topicId = "topic_id"
        case topicName = "topic_name"
        case subjectId = "subject_id"
        case completedAt = "completed_at"
        case score
    }
}
