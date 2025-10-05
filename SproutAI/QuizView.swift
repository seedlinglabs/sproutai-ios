//
//  QuizView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI
import Combine

// MARK: - Quiz View Model
@MainActor
class QuizViewModel: ObservableObject {
    @Published var questions: [QuizQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var selectedAnswer: Int? = nil
    @Published var showResult: Bool = false
    @Published var showExplanation: Bool = false
    @Published var results: [QuizResult] = []
    @Published var isQuizCompleted: Bool = false
    @Published var startTime: Date = Date()
    @Published var questionStartTime: Date = Date()
    
    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(questions.count)
    }
    
    var score: Int {
        results.filter { $0.isCorrect }.count
    }
    
    var totalQuestions: Int {
        questions.count
    }
    
    func loadQuestions(from assessmentString: String) {
        questions = QuizParser.parse(assessmentString)
        resetQuiz()
    }
    
    func selectAnswer(_ answerIndex: Int) {
        selectedAnswer = answerIndex
    }
    
    func submitAnswer() {
        guard let currentQuestion = currentQuestion,
              let selectedAnswer = selectedAnswer else { return }
        
        let isCorrect = selectedAnswer == currentQuestion.correctAnswer
        let timeSpent = Date().timeIntervalSince(questionStartTime)
        
        let result = QuizResult(
            questionId: currentQuestion.id,
            selectedAnswer: selectedAnswer,
            isCorrect: isCorrect,
            timeSpent: timeSpent
        )
        
        results.append(result)
        showResult = true
        
        if currentQuestion.explanation != nil {
            showExplanation = true
        }
    }
    
    func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            showResult = false
            showExplanation = false
            questionStartTime = Date()
        } else {
            isQuizCompleted = true
        }
    }
    
    func resetQuiz() {
        currentQuestionIndex = 0
        selectedAnswer = nil
        showResult = false
        showExplanation = false
        results.removeAll()
        isQuizCompleted = false
        startTime = Date()
        questionStartTime = Date()
    }
}

// MARK: - Quiz Parser
struct QuizParser {
    static func parse(_ assessmentString: String) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        
        // Try different parsing strategies
        if let jsonQuestions = parseJSON(assessmentString) {
            return jsonQuestions
        } else if let markdownQuestions = parseMarkdown(assessmentString) {
            return markdownQuestions
        } else if let plainTextQuestions = parsePlainText(assessmentString) {
            return plainTextQuestions
        }
        
        return questions
    }
    
    // Parse JSON format
    private static func parseJSON(_ text: String) -> [QuizQuestion]? {
        guard let data = text.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            if let questions = try? decoder.decode([QuizQuestionJSON].self, from: data) {
                return questions.map { $0.toQuizQuestion() }
            }
            
            if let wrapper = try? decoder.decode(QuizWrapper.self, from: data) {
                return wrapper.questions.map { $0.toQuizQuestion() }
            }
        } catch {
            print("[DEBUG][QuizParser] JSON parsing failed: \(error)")
        }
        
        return nil
    }
    
    // Parse Markdown format
    private static func parseMarkdown(_ text: String) -> [QuizQuestion]? {
        var questions: [QuizQuestion] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentQuestion: String?
        var currentOptions: [String] = []
        var correctAnswer: Int = 0
        var explanation: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty { continue }
            
            // Question line (starts with number or Q)
            if trimmed.range(of: #"^\d+\.?\s*"#, options: .regularExpression) != nil ||
               trimmed.lowercased().hasPrefix("q") ||
               trimmed.hasSuffix("?") {
                
                // Save previous question
                if let question = currentQuestion, !currentOptions.isEmpty {
                    questions.append(QuizQuestion(
                        question: question,
                        options: currentOptions,
                        correctAnswer: correctAnswer,
                        explanation: explanation
                    ))
                }
                
                // Start new question
                currentQuestion = trimmed.replacingOccurrences(of: #"^\d+\.?\s*"#, with: "", options: .regularExpression)
                currentOptions = []
                correctAnswer = 0
                explanation = nil
                
            } else if trimmed.range(of: #"^[A-D][\)\.]\s*"#, options: .regularExpression) != nil {
                // Option line (A), B), C., D.
                let option = trimmed.replacingOccurrences(of: #"^[A-D][\)\.]\s*"#, with: "", options: .regularExpression)
                currentOptions.append(option)
                
                // Check if this is marked as correct answer
                if trimmed.contains("*") || trimmed.contains("✓") || trimmed.contains("[CORRECT]") {
                    correctAnswer = currentOptions.count - 1
                }
                
            } else if trimmed.lowercased().hasPrefix("answer:") || trimmed.lowercased().hasPrefix("correct:") {
                // Extract correct answer
                let answerPart = trimmed.replacingOccurrences(of: #"^(answer|correct):\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
                if let answerLetter = answerPart.first?.uppercased(),
                   let index = ["A", "B", "C", "D"].firstIndex(of: answerLetter) {
                    correctAnswer = index
                }
                
            } else if trimmed.lowercased().hasPrefix("explanation:") {
                explanation = trimmed.replacingOccurrences(of: #"^explanation:\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            }
        }
        
        // Add last question
        if let question = currentQuestion, !currentOptions.isEmpty {
            questions.append(QuizQuestion(
                question: question,
                options: currentOptions,
                correctAnswer: correctAnswer,
                explanation: explanation
            ))
        }
        
        return questions.isEmpty ? nil : questions
    }
    
    // Parse plain text format
    private static func parsePlainText(_ text: String) -> [QuizQuestion]? {
        let sections = text.components(separatedBy: "\n\n")
        var questions: [QuizQuestion] = []
        
        for section in sections {
            let lines = section.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            
            guard lines.count >= 3 else { continue }
            
            let question = lines[0]
            let options = Array(lines[1..<min(lines.count, 5)])
            
            questions.append(QuizQuestion(
                question: question,
                options: options,
                correctAnswer: 0,
                explanation: nil
            ))
        }
        
        return questions.isEmpty ? nil : questions
    }
}

// MARK: - Quiz Main View
struct QuizView: View {
    let topic: SproutTopicWithCompletion
    @Binding var isPresented: Bool
    @StateObject private var quizVM = QuizViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                if quizVM.questions.isEmpty {
                    loadingOrErrorView
                } else if quizVM.isQuizCompleted {
                    QuizResultsView(quizVM: quizVM, topic: topic, isPresented: $isPresented)
                } else {
                    QuizQuestionView(quizVM: quizVM)
                }
            }
            .navigationTitle(topic.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                if !quizVM.questions.isEmpty && !quizVM.isQuizCompleted {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(quizVM.currentQuestionIndex + 1)/\(quizVM.totalQuestions)")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }
            .onAppear {
                loadQuiz()
            }
        }
    }
    
    private var loadingOrErrorView: some View {
        VStack(spacing: 16) {
            if let assessmentQuestions = topic.aiContent?.assessmentQuestions,
               !assessmentQuestions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Loading Quiz...")
                    .font(.headline)
                    .foregroundColor(.white)
                
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("No Quiz Available")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("This topic doesn't have assessment questions yet.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    private func loadQuiz() {
        guard let assessmentQuestions = topic.aiContent?.assessmentQuestions,
              !assessmentQuestions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            quizVM.loadQuestions(from: assessmentQuestions)
        }
    }
}