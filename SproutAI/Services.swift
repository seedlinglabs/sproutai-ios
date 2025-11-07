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
        case assessmentQuestions = "assessmentQuestions"
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

// MARK: - Learning Assist Service
class LearningAssistService {
    private let baseURL = "https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod"
    
    func markTopicAsComplete(topicId: String, userId: String, completion: @escaping (Result<MarkCompleteResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/learning-assist/mark-complete") else { 
            completion(.failure(URLError(.badURL)))
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let body: [String: Any] = [
            "topic_id": topicId,
            "user_id": userId,
            "completion_timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        #if DEBUG
        if let payload = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
           let payloadString = String(data: payload, encoding: .utf8) {
            print("[DEBUG][AuthService] OTP send payload:\n\(payloadString)")
        }
        #endif
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            print("[DEBUG][LearningAssistService] Mark complete response: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("[DEBUG][LearningAssistService] Error response: \(errorString)")
                }
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(MarkCompleteResponse.self, from: data)
                completion(.success(response))
            } catch {
                print("[DEBUG][LearningAssistService] Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func getLearningProgress(userId: String, completion: @escaping (Result<LearningProgressResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/learning-assist/progress/\(userId)") else { 
            completion(.failure(URLError(.badURL)))
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            print("[DEBUG][LearningAssistService] Progress response: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("[DEBUG][LearningAssistService] Error response: \(errorString)")
                }
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(LearningProgressResponse.self, from: data)
                completion(.success(response))
            } catch {
                print("[DEBUG][LearningAssistService] Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
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
    private let userDefaults = UserDefaults.standard
    private let tokenDefaultsKey = "sproutai.auth.token"
    private let parentDefaultsKey = "sproutai.auth.parent"
    private var lastOTPRequestId: String?
    
    init() {
        checkAuth()
    }
    
    // MARK: - Session Persistence
    private func loadPersistedSession() -> (Parent, String)? {
        guard
            let storedToken = userDefaults.string(forKey: tokenDefaultsKey),
            let parentData = userDefaults.data(forKey: parentDefaultsKey)
        else {
            return nil
        }
        
        do {
            let storedParent = try JSONDecoder().decode(Parent.self, from: parentData)
            return (storedParent, storedToken)
        } catch {
            print("[DEBUG][AuthService] Failed to decode stored parent: \(error)")
            userDefaults.removeObject(forKey: parentDefaultsKey)
            return nil
        }
    }
    
    private func persistSession(parent: Parent, token: String) {
        do {
            let encodedParent = try JSONEncoder().encode(parent)
            userDefaults.set(encodedParent, forKey: parentDefaultsKey)
            userDefaults.set(token, forKey: tokenDefaultsKey)
        } catch {
            print("[DEBUG][AuthService] Failed to persist parent: \(error)")
        }
    }
    
    private func clearPersistedSession() {
        userDefaults.removeObject(forKey: parentDefaultsKey)
        userDefaults.removeObject(forKey: tokenDefaultsKey)
    }
    
    private func handleExpiredSession() {
        clearPersistedSession()
        parent = nil
        token = nil
        authState = .unauthenticated
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
        
        if let (storedParent, storedToken) = loadPersistedSession() {
            print("[DEBUG][AuthService] Restoring persisted session for user: \(storedParent.userId)")
            parent = storedParent
            token = storedToken
            authState = .authenticated
            
            verifyToken(token: storedToken) { [weak self] result in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("[DEBUG][AuthService] Token verification succeeded for stored session")
                    case .failure(let error as NSError):
                        if error.domain == "APIError", error.code == 401 {
                            print("[DEBUG][AuthService] Stored token invalid or expired")
                            self.handleExpiredSession()
                        } else {
                            print("[DEBUG][AuthService] Token verification failed but keeping cached session: \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        print("[DEBUG][AuthService] Token verification failed but keeping cached session: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("[DEBUG][AuthService] No persisted session found; requiring login")
            authState = .unauthenticated
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
                        let message = apiError.displayMessage
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Token verification failed"])))
                    }
                    return
                }
                
                do {
                    let parent = try JSONDecoder().decode(Parent.self, from: data)
                    Task { @MainActor in
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
        persistSession(parent: parent, token: token)
        self.authState = .authenticated
    }
    
    func login(identifier: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/login") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let numericOnly = trimmedIdentifier.filter(\.isNumber)
        let looksLikeEmail = trimmedIdentifier.contains("@")
        
        var body: [String: Any] = [
            "password": password,
            "device_type": "ios",
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]

        // Handle email login
        if looksLikeEmail {
            body["email"] = trimmedIdentifier.lowercased()
            body["login_with"] = "email"
        }
        // Handle phone login
        else if numericOnly.count >= 6 {
            // Format phone number with country code
            let phoneWithCode: String
            if numericOnly.count == 10 {
                // Indian 10-digit number - add +91 prefix
                phoneWithCode = "+91\(numericOnly)"
                body["country_code"] = "+91"
            } else if numericOnly.hasPrefix("91") && numericOnly.count == 12 {
                // Already has 91 prefix - add +
                phoneWithCode = "+\(numericOnly)"
                body["country_code"] = "+91"
            } else if numericOnly.hasPrefix("+") {
                // Already properly formatted
                phoneWithCode = numericOnly
            } else {
                // Unknown format - try as-is with +91
                phoneWithCode = "+91\(numericOnly)"
                body["country_code"] = "+91"
            }
            
            body["phone_number"] = phoneWithCode
            body["phone"] = phoneWithCode
            body["user_type"] = "parent"
            body["login_with"] = "phone"
        }

        guard body["email"] != nil || body["phone_number"] != nil else {
            completion(.failure(NSError(
                domain: "AuthValidation",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address or phone number."]
            )))
            return
        }

#if DEBUG
        print("[DEBUG][AuthService] ===== LOGIN REQUEST =====")
        print("[DEBUG][AuthService] URL: \(url.absoluteString)")
        if let debugPayload = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let payloadString = String(data: debugPayload, encoding: .utf8) {
            print("[DEBUG][AuthService] Request Body:")
            print(payloadString)
        }
        print("[DEBUG][AuthService] ============================")
#endif

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
                        let message = apiError.displayMessage
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode)"])))
                    }
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
                    Task { @MainActor in
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
                        let message = apiError.displayMessage
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode)"])))
                    }
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
                    Task { @MainActor in
                        self.setAuthenticated(parent: resp.user, token: resp.token)
                    }
                    completion(.success(resp))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - OTP Login Methods
    func sendOTP(phoneNumber: String, completion: @escaping (Result<OTPResponse, Error>) -> Void) {
        let normalizedPhone = phoneNumber.filter(\.isNumber)
        
        guard normalizedPhone.count >= 6 else {
            completion(.failure(NSError(
                domain: "AuthValidation",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Enter a valid phone number before requesting an OTP."]
            )))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/send-otp") else { return }
        lastOTPRequestId = nil
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Format phone number with country code
        let phoneWithCode: String
        if normalizedPhone.count == 10 {
            // Indian 10-digit number - add +91 prefix
            phoneWithCode = "+91\(normalizedPhone)"
        } else if normalizedPhone.hasPrefix("91") && normalizedPhone.count == 12 {
            // Already has 91 prefix - add +
            phoneWithCode = "+\(normalizedPhone)"
        } else {
            // Unknown format - try as-is with +91
            phoneWithCode = "+91\(normalizedPhone)"
        }
        
        var body: [String: Any] = [
            "phone_number": phoneWithCode,
            "phone": phoneWithCode,
            "country_code": "+91",
            "user_type": "parent",
            "device_type": "ios",
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]

#if DEBUG
        print("[DEBUG][AuthService] ===== SEND OTP REQUEST =====")
        print("[DEBUG][AuthService] URL: \(url.absoluteString)")
        if let debugPayload = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let payloadString = String(data: debugPayload, encoding: .utf8) {
            print("[DEBUG][AuthService] Request Body:")
            print(payloadString)
        }
        print("[DEBUG][AuthService] =================================")
#endif
        
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
                print("[DEBUG] OTP send response: \(httpResponse.statusCode)")
                print("[DEBUG] Raw response: \n" + (String(data: data, encoding: .utf8) ?? "(not UTF-8)"))

                guard (200...299).contains(httpResponse.statusCode) else {
                    if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        let message = apiError.displayMessage
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode)"])))
                    }
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(OTPResponse.self, from: data)
                    if resp.success {
                        self.lastOTPRequestId = resp.otpId
                    }
                    completion(.success(resp))
                } catch {
                    print("[DEBUG] OTP send decoding error: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func verifyOTP(phoneNumber: String, otp: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let normalizedPhone = phoneNumber.filter(\.isNumber)
        
        guard normalizedPhone.count >= 6 else {
            completion(.failure(NSError(
                domain: "AuthValidation",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Enter the phone number used to request the OTP."]
            )))
            return
        }
        
        guard otp.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 else {
            completion(.failure(NSError(
                domain: "AuthValidation",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Enter the 4 or 6 digit OTP sent to your phone."]
            )))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/verify-otp") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Format phone number with country code (same as sendOTP)
        let phoneWithCode: String
        if normalizedPhone.count == 10 {
            phoneWithCode = "+91\(normalizedPhone)"
        } else if normalizedPhone.hasPrefix("91") && normalizedPhone.count == 12 {
            phoneWithCode = "+\(normalizedPhone)"
        } else {
            phoneWithCode = "+91\(normalizedPhone)"
        }

        var body: [String: Any] = [
            "phone_number": phoneWithCode,
            "phone": phoneWithCode,
            "otp": otp,
            "country_code": "+91",
            "user_type": "parent",
            "device_type": "ios",
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        if let otpId = lastOTPRequestId {
            body["otp_id"] = otpId
        }
        
#if DEBUG
        print("[DEBUG][AuthService] ===== VERIFY OTP REQUEST =====")
        print("[DEBUG][AuthService] URL: \(url.absoluteString)")
        if let payload = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let payloadString = String(data: payload, encoding: .utf8) {
            print("[DEBUG][AuthService] Request Body:")
            print(payloadString)
        }
        print("[DEBUG][AuthService] ====================================")
#endif
        
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
                print("[DEBUG] OTP verify response: \(httpResponse.statusCode)")
                print("[DEBUG] Raw response: \n" + (String(data: data, encoding: .utf8) ?? "(not UTF-8)"))

                guard (200...299).contains(httpResponse.statusCode) else {
                    if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        let message = apiError.displayMessage
                        completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode)"])))
                    }
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
                    Task { @MainActor in
                        self.setAuthenticated(parent: resp.user, token: resp.token)
                    }
                    self.lastOTPRequestId = nil
                    completion(.success(resp))
                } catch {
                    print("[DEBUG] OTP verify decoding error: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func logout() {
        let currentToken = self.token
        
        handleExpiredSession()

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
                        print("[DEBUG] Logout API error: \(apiError.displayMessage)")
                    }
                }
            }
        }
    }
}
