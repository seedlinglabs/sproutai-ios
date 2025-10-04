//
//  Services.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Academic Records Service
class AcademicRecordsService {
    private let baseURL = "https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod"
    
    func getRecordsForParent(schoolId: String, academicYear: String, classAccess: [String]) async throws -> [SproutAcademicRecord] {
        print("[DEBUG][AcademicRecordsService] Mock: Fetching records for schoolId=\(schoolId), year=\(academicYear), classes=\(classAccess)")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Return empty data for now - replace with actual API call
        return []
    }
}

// MARK: - Topics Service
class TopicsService {
    private let baseURL = "https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod"
    
    func getTopics(subjectId: String) async throws -> [SproutTopic] {
        print("[DEBUG][TopicsService] Mock: Fetching topics for subjectId=\(subjectId)")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Return empty data for now - replace with actual API call
        return []
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