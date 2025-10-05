//
//  Services.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - API Models

// Academic Records API Models
struct AcademicRecord: Codable {
    let recordId: String
    let topicId: String
    let schoolId: String
    let academicYear: String
    let grade: String
    let section: String
    let subjectId: String
    let subjectName: String
    let topicName: String
    let teacherId: String?
    let teacherName: String?
    let status: String // "not_started", "in_progress", "completed", "on_hold", "cancelled"
    let notes: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case topicId = "topic_id"
        case schoolId = "school_id"
        case academicYear = "academic_year"
        case grade, section
        case subjectId = "subject_id"
        case subjectName = "subject_name"
        case topicName = "topic_name"
        case teacherId = "teacher_id"
        case teacherName = "teacher_name"
        case status, notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Topics API Models
struct Topic: Codable {
    let id: String
    let name: String
    let description: String?
    let subjectId: String
    let schoolId: String
    let classId: String
    let createdAt: String
    let updatedAt: String
    let aiContent: AIContent?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case subjectId = "subject_id"
        case schoolId = "school_id"
        case classId = "class_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case aiContent = "ai_content"
    }
}

struct AIContent: Codable {
    let lessonPlan: String?
    let teachingGuide: String?
    let groupDiscussion: String?
    let assessmentQuestions: String?
    let worksheets: String?
    let videos: [Video]?
    let generatedAt: String?
    let classLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case lessonPlan = "lesson_plan"
        case teachingGuide = "teaching_guide"
        case groupDiscussion = "group_discussion"
        case assessmentQuestions = "assessment_questions"
        case worksheets
        case videos
        case generatedAt = "generated_at"
        case classLevel = "class_level"
    }
    
    func toSproutAIContent() -> SproutAIContent {
        return SproutAIContent(
            summary: lessonPlan, // Map lesson plan to summary for compatibility
            videos: videos?.map { $0.toSproutVideo() },
            assessmentQuestions: assessmentQuestions
        )
    }
}

struct Video: Codable {
    let title: String
    let url: String
    let duration: String?
    
    func toSproutVideo() -> SproutVideo {
        return SproutVideo(
            title: title,
            url: url,
            duration: duration
        )
    }
}

// Static Data Models
struct School: Codable {
    let id: String
    let name: String
    let description: String?
    let classes: [Class]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, classes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Class: Codable {
    let id: String
    let name: String
    let description: String?
    let subjects: [Subject]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, subjects
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Subject: Codable {
    let id: String
    let name: String
    let description: String?
    let topics: [Topic]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, topics
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Academic Records Service
class AcademicRecordsService {
    private let baseURL = "https://a34mmmc1te.execute-api.us-west-2.amazonaws.com/pre-prod"
    
    func getRecordsForParent(schoolId: String, academicYear: String, classAccess: [String]) async throws -> [SproutAcademicRecord] {
        print("[DEBUG][AcademicRecordsService] Fetching records for schoolId=\(schoolId), year=\(academicYear), classes=\(classAccess)")
        
        var allRecords: [SproutAcademicRecord] = []
        
        // Fetch records for each class the parent has access to
        for classAccess in classAccess {
            // Extract grade and section from class access (e.g., "5A" -> grade="5", section="A")
            let grade = String(classAccess.dropLast())
            let section = String(classAccess.suffix(1))
            
            do {
                let records = try await fetchAcademicRecords(
                    schoolId: schoolId,
                    academicYear: academicYear,
                    grade: grade,
                    section: section
                )
                allRecords.append(contentsOf: records)
            } catch {
                print("[DEBUG][AcademicRecordsService] Failed to fetch records for \(classAccess): \(error)")
                // Continue with other classes even if one fails
            }
        }
        
        print("[DEBUG][AcademicRecordsService] Retrieved \(allRecords.count) total academic records")
        return allRecords
    }
    
    private func fetchAcademicRecords(schoolId: String, academicYear: String, grade: String, section: String) async throws -> [SproutAcademicRecord] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/academic-records") else {
            throw URLError(.badURL)
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "school_id", value: schoolId),
            URLQueryItem(name: "academic_year", value: academicYear),
            URLQueryItem(name: "grade", value: grade),
            URLQueryItem(name: "section", value: section)
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        print("[DEBUG][AcademicRecordsService] Making request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("[DEBUG][AcademicRecordsService] Response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("[DEBUG][AcademicRecordsService] Error response: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Parse the API response
        let apiRecords = try JSONDecoder().decode([AcademicRecord].self, from: data)
        
        // Convert API models to our app models
        let sproutRecords = apiRecords.map { apiRecord in
            SproutAcademicRecord(
                id: apiRecord.recordId,
                userId: "parent-user", // This would come from auth context
                subjectId: apiRecord.subjectId,
                subjectName: apiRecord.subjectName,
                topicId: apiRecord.topicId,
                topicName: apiRecord.topicName,
                grade: apiRecord.grade,
                section: apiRecord.section,
                status: apiRecord.status,
                score: nil, // API doesn't provide score, could be added later
                createdAt: apiRecord.createdAt,
                updatedAt: apiRecord.updatedAt
            )
        }
        
        print("[DEBUG][AcademicRecordsService] Converted \(sproutRecords.count) records for \(grade)\(section)")
        return sproutRecords
    }
}

// MARK: - Topics Service
class TopicsService {
    private let baseURL = "https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod"
    
    func getTopicsLightweight(subjectId: String) async throws -> [SproutTopic] {
        print("[DEBUG][TopicsService] Fetching lightweight topics for subjectId=\(subjectId)")
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/topics") else {
            throw URLError(.badURL)
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "subject_id", value: subjectId)
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        print("[DEBUG][TopicsService] Making lightweight request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("[DEBUG][TopicsService] Lightweight response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("[DEBUG][TopicsService] Error response: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Parse the API response
        let apiTopics = try JSONDecoder().decode([Topic].self, from: data)
        
        // Convert API models to our app models but strip out heavy AI content
        let lightweightTopics = apiTopics.map { apiTopic in
            SproutTopic(
                id: apiTopic.id,
                name: apiTopic.name,
                description: apiTopic.description,
                subjectId: apiTopic.subjectId,
                schoolId: apiTopic.schoolId,
                classId: apiTopic.classId,
                createdAt: apiTopic.createdAt,
                updatedAt: apiTopic.updatedAt,
                aiContent: nil // Explicitly set to nil to avoid heavy content
            )
        }
        
        print("[DEBUG][TopicsService] Returning \(lightweightTopics.count) lightweight topics for subjectId=\(subjectId)")
        return lightweightTopics
    }
    
    func getTopics(subjectId: String) async throws -> [SproutTopic] {
        print("[DEBUG][TopicsService] Fetching topics for subjectId=\(subjectId)")
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/topics") else {
            throw URLError(.badURL)
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "subject_id", value: subjectId)
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        print("[DEBUG][TopicsService] Making request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("[DEBUG][TopicsService] Response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("[DEBUG][TopicsService] Error response: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Parse the API response
        let apiTopics = try JSONDecoder().decode([Topic].self, from: data)
        
        // Convert API models to our app models
        let sproutTopics = apiTopics.map { apiTopic in
            SproutTopic(
                id: apiTopic.id,
                name: apiTopic.name,
                description: apiTopic.description,
                subjectId: apiTopic.subjectId,
                schoolId: apiTopic.schoolId,
                classId: apiTopic.classId,
                createdAt: apiTopic.createdAt,
                updatedAt: apiTopic.updatedAt,
                aiContent: apiTopic.aiContent?.toSproutAIContent()
            )
        }
        
        print("[DEBUG][TopicsService] Returning \(sproutTopics.count) topics for subjectId=\(subjectId)")
        return sproutTopics
    }
    
    func getTopic(id: String) async throws -> SproutTopic? {
        print("[DEBUG][TopicsService] Fetching topic with id=\(id)")
        
        guard let url = URL(string: "\(baseURL)/topics/\(id)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        print("[DEBUG][TopicsService] Making request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("[DEBUG][TopicsService] Response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                return nil // Topic not found
            }
            if let errorString = String(data: data, encoding: .utf8) {
                print("[DEBUG][TopicsService] Error response: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Parse the API response
        let apiTopic = try JSONDecoder().decode(Topic.self, from: data)
        
        // Convert API model to our app model
        let sproutTopic = SproutTopic(
            id: apiTopic.id,
            name: apiTopic.name,
            description: apiTopic.description,
            subjectId: apiTopic.subjectId,
            schoolId: apiTopic.schoolId,
            classId: apiTopic.classId,
            createdAt: apiTopic.createdAt,
            updatedAt: apiTopic.updatedAt,
            aiContent: apiTopic.aiContent?.toSproutAIContent()
        )
        
        print("[DEBUG][TopicsService] Returning topic: \(sproutTopic.name)")
        return sproutTopic
    }
}

// MARK: - Authentication Service
@MainActor
class AuthService: ObservableObject {
    @Published var authState: AuthState = .checking
    @Published var parent: Parent? = nil
    @Published var token: String? = nil
    
    private let baseURL = "https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod"
    
    init() {
        checkAuth()
    }
    
    // MARK: - Networking Helpers
    private func shouldRetry(error: Error?, response: HTTPURLResponse?) -> Bool {
        if let error = error as? URLError {
            switch error.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet, .internationalRoamingOff, .callIsActive, .dataNotAllowed:
                return true
            default:
                break
            }
        }
        if let status = response?.statusCode, (500...599).contains(status) {
            return true
        }
        return false
    }
    
    private func createAuthenticatedRequest(url: URL, method: String = "GET", token: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        if let token = token ?? self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }

    private func requestWithRetry(_ request: URLRequest, attempts: Int = 3, initialBackoff: Double = 0.5, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        func attempt(remaining: Int, backoff: Double) {
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, let data = data {
                    if self.shouldRetry(error: error, response: httpResponse) && remaining > 1 {
                        let nextBackoff = backoff * 2
                        DispatchQueue.global().asyncAfter(deadline: .now() + backoff) {
                            attempt(remaining: remaining - 1, backoff: nextBackoff)
                        }
                        return
                    }
                    completion(.success((data, httpResponse)))
                    return
                }
                if self.shouldRetry(error: error, response: response as? HTTPURLResponse), remaining > 1 {
                    let nextBackoff = backoff * 2
                    DispatchQueue.global().asyncAfter(deadline: .now() + backoff) {
                        attempt(remaining: remaining - 1, backoff: nextBackoff)
                    }
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                }
            }.resume()
        }
        attempt(remaining: attempts, backoff: initialBackoff)
    }
    
    func checkAuth() {
        print("[DEBUG][AuthService] Checking authentication state...")
        
        // Add a small delay to show the checking state briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // TODO: Implement secure token check with Keychain
            // For now, always start unauthenticated
            print("[DEBUG][AuthService] Setting state to unauthenticated")
            self.authState = .unauthenticated
        }
    }
    
    func verifyToken(token: String, completion: @escaping (Result<Parent, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/verify") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        print("[DEBUG][AuthService] Verifying token...")
        
        self.requestWithRetry(request, attempts: 2, initialBackoff: 0.5) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (data, httpResponse)):
                print("[DEBUG] Token verification response: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: apiError.error])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Token verification failed"])))
                    }
                    return
                }
                
                do {
                    let parent = try JSONDecoder().decode(Parent.self, from: data)
                    DispatchQueue.main.async {
                        self.setAuthenticated(parent: parent, token: token)
                    }
                    completion(.success(parent))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func setAuthenticated(parent: Parent, token: String) {
        self.parent = parent
        self.token = token
        self.authState = .authenticated
    }
    
    func login(phoneNumber: String, name: String?, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/login") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let normalizedPhone = phoneNumber.filter(\.isNumber)
        let body = LoginRequest(phoneNumber: normalizedPhone, name: name)
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }

        self.requestWithRetry(request, attempts: 3, initialBackoff: 0.5) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (data, httpResponse)):
                print("[DEBUG] Raw response: \n" + (String(data: data, encoding: .utf8) ?? "(not UTF-8)"))

                guard (200...299).contains(httpResponse.statusCode) else {
                    if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: apiError.error])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode)"])))
                    }
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.setAuthenticated(parent: resp.user, token: resp.token)
                    }
                    completion(.success(resp))
                } catch {
                    print("[DEBUG] Decoding error: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func register(fullName: String, email: String, phoneNumber: String, password: String, grades: [String], sections: [String], schoolId: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/register") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let normalizedPhone = phoneNumber.filter(\.isNumber)
        let body: [String: Any] = [
            "name": fullName,
            "email": email,
            "phone_number": normalizedPhone,
            "password": password,
            "user_type": "parent",
            "school_id": schoolId,
            "class_access": grades.flatMap { g in sections.map { "\(g)\($0)" } }
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        self.requestWithRetry(request, attempts: 3, initialBackoff: 0.5) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (data, httpResponse)):
                print("[DEBUG] Raw response: \n" + (String(data: data, encoding: .utf8) ?? "(not UTF-8)"))

                guard (200...299).contains(httpResponse.statusCode) else {
                    if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: apiError.error])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode)"])))
                    }
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.setAuthenticated(parent: resp.user, token: resp.token)
                    }
                    completion(.success(resp))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func logout() {
        let currentToken = self.token
        
        // TODO: Implement Keychain token removal
        self.parent = nil
        self.token = nil
        self.authState = .unauthenticated

        guard let token = currentToken, let url = URL(string: "\(baseURL)/auth/logout") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        self.requestWithRetry(request, attempts: 2, initialBackoff: 0.5) { result in
            switch result {
            case .failure(let error):
                print("[DEBUG] Logout network error: \(error)")
            case .success(let (data, httpResponse)):
                print("[DEBUG] Raw response: \n" + (String(data: data, encoding: .utf8) ?? "(not UTF-8)"))
                if !(200...299).contains(httpResponse.statusCode) {
                    if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        print("[DEBUG] Logout API error: \(apiError.error)")
                    }
                }
            }
        }
    }
}