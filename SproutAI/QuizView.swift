//
//  QuizView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI
import Combine
import FoundationModels

// MARK: - Quiz View Model
@MainActor
class QuizViewModel: ObservableObject {
    @Published var questions: [QuizQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var selectedAnswer: Int? = nil
    @Published var shortAnswerText: String = "" // NEW: For non-multiple choice answers
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
        // Only count multiple choice questions (those with options) for scoring
        let mcResults: [QuizResult] = results.enumerated().compactMap { (index, result) in
            guard index < questions.count else { return nil }
            let question = questions[index]
            return question.options.isEmpty ? nil : result
        }
        return mcResults.filter { $0.isCorrect }.count
    }
    
    var totalMultipleChoiceQuestions: Int {
        questions.filter { !$0.options.isEmpty }.count
    }
    
    var totalQuestions: Int {
        questions.count
    }
    
    func loadQuestions(from assessmentString: String) async {
        questions = await QuizParser.parse(assessmentString)
        resetQuiz()
        
        // Pre-populate text for the first question if it's non-MC
        if let firstQuestion = currentQuestion,
           firstQuestion.options.isEmpty,
           let explanation = firstQuestion.explanation {
            shortAnswerText = explanation
        }
    }
    
    func selectAnswer(_ answerIndex: Int) {
        selectedAnswer = answerIndex
    }
    
    func submitAnswer() {
        guard let currentQuestion = currentQuestion else { return }
        
        let isMC = !currentQuestion.options.isEmpty
        let timeSpent = Date().timeIntervalSince(questionStartTime)
        
        if isMC {
            // Handle Multiple Choice
            guard let selectedAnswer = selectedAnswer else { return }
            
            let isCorrect = selectedAnswer == currentQuestion.correctAnswer
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
        } else {
            // Handle Non-Multiple Choice (Reference Answer)
            // No validation needed since it's just for viewing reference
            
            let result = QuizResult(
                questionId: currentQuestion.id,
                selectedAnswer: -1, // Placeholder for non-MC
                submittedText: shortAnswerText, // Pre-populated reference answer
                isCorrect: false, // Not scored
                timeSpent: timeSpent
            )
            
            results.append(result)
            showResult = true
            
            // Don't show explanation for non-MC since reference answer is already visible
            // showExplanation = false (already false by default)
        }
    }
    
    func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            shortAnswerText = "" // Reset first, then populate if needed
            showResult = false
            showExplanation = false
            questionStartTime = Date()
            
            // Pre-populate text for non-MC questions with the explanation/answer
            if let currentQuestion = currentQuestion,
               currentQuestion.options.isEmpty,
               let explanation = currentQuestion.explanation {
                shortAnswerText = explanation
            }
        } else {
            isQuizCompleted = true
        }
    }
    
    func resetQuiz() {
        currentQuestionIndex = 0
        selectedAnswer = nil
        shortAnswerText = "" // Reset first, then populate if needed
        showResult = false
        showExplanation = false
        results.removeAll()
        isQuizCompleted = false
        startTime = Date()
        questionStartTime = Date()
        
        // Pre-populate text for the first question if it's non-MC
        if let firstQuestion = currentQuestion,
           firstQuestion.options.isEmpty,
           let explanation = firstQuestion.explanation {
            shortAnswerText = explanation
        }
    }
}

// MARK: - Quiz Parser
struct QuizParser {

    /// The main entry function: Uses on-device AI to convert text to structured questions.
    static func parse(_ assessmentString: String) async -> [QuizQuestion] {
        // Input validation
        let trimmedInput = assessmentString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            print("[DEBUG][QuizParser] Empty assessment string provided")
            return []
        }
        
        // Use on-device AI to convert to structured JSON
        if let aiQuestions = await parseWithFoundationModels(trimmedInput) {
            // Post-process to ensure proper question type detection
            return aiQuestions.map { validateAndCleanQuestion($0) }
        }
        
        // If AI parsing fails, return empty array
        print("[DEBUG][QuizParser] Foundation Models parsing failed, no questions returned.")
        return []
    }

    /// Post-processing validation to ensure proper question type detection
    private static func validateAndCleanQuestion(_ question: QuizQuestion) -> QuizQuestion {
        // Check if this should be an open-ended question based on the question text
        let questionText = question.question.lowercased()
        let openEndedKeywords = [
            "explain", "describe", "discuss", "write", "list", "give examples",
            "in your own words", "what do you think", "how would you",
            "short answer", "long answer", "essay", "paragraph"
        ]
        
        let containsOpenEndedKeyword = openEndedKeywords.contains { keyword in
            questionText.contains(keyword)
        }
        
        // If the question contains open-ended keywords and has only 1 option, 
        // it's likely misclassified as MC when it should be open-ended
        if containsOpenEndedKeyword && question.options.count <= 1 {
            print("[DEBUG][QuizParser] Converting to open-ended: \(question.question)")
            return QuizQuestion(
                question: question.question,
                options: [], // Clear options
                correctAnswer: -1, // Set to open-ended indicator
                explanation: question.explanation
            )
        }
        
        // If it has 1 option but no open-ended keywords, it might still be misclassified
        if question.options.count == 1 {
            print("[DEBUG][QuizParser] Warning: Question with single option detected: \(question.question)")
            // For safety, convert single-option questions to open-ended
            return QuizQuestion(
                question: question.question,
                options: [], // Clear options
                correctAnswer: -1, // Set to open-ended indicator
                explanation: question.explanation
            )
        }
        
        return question
    }

    // MARK: - AI-Powered Parsing with Foundation Models
    @MainActor
    private static func parseWithFoundationModels(_ assessmentString: String) async -> [QuizQuestion]? {
        let model = SystemLanguageModel.default
        
        // Check if the model is available
        guard case .available = model.availability else {
            print("[DEBUG][QuizParser] Foundation Models not available: \(model.availability)")
            return nil
        }
        
        // --- FINAL REVISED INSTRUCTIONS (SYSTEM ROLE) ---
        let instructions = """
        You are an expert data extraction API. Your sole purpose is to convert unstructured quiz text into a VALID JSON array matching the provided schema.

        Schema Rules:
        1. The object schema is: [{"question": string, "options": [string], "correctAnswer": number, "explanation": string}]
        2. FOR MULTIPLE CHOICE QUESTIONS (questions with A, B, C, D options listed):
           - Populate "options" array with the provided choices.
           - The 'Answer' key might be a letter (A, B, C, D) OR the full correct phrase/word from the options.
           - If the Answer is a phrase (not a single letter): You MUST search for the phrase within the options list and use its position (0-based index) for "correctAnswer". IGNORE THE FIRST LETTER of the answer phrase; it is not the option letter.
           - You MUST convert the correct answer (whether letter or phrase) into a **0-based numerical index** for the "correctAnswer" field. (A=0, B=1, C=2, D=3).
           - TRIPLE-CHECK that the resulting index is correct.
        3. FOR OPEN-ENDED QUESTIONS (Short Answer/Long Answer/CFU or questions WITHOUT multiple choice options A, B, C, D):
           - "options" MUST be an empty array ([]).
           - "correctAnswer" MUST be -1.
           - Use the 'Sample Answer' or 'Parent Guidance' as the value for the "explanation" field.
        4. CRITICAL: If you do not see explicit A, B, C, D choice options listed in the question, it is an OPEN-ENDED question and must have empty options array.
        5. DO NOT include any preamble, markdown formatting (like ```json), or conversational text in the final output. Return ONLY the raw JSON array.
        """
        
        // --- FINAL REVISED PROMPT (USER TASK) ---
        let prompt = """
        Parse this assessment text and convert it to a JSON array of quiz questions.

        Example input demonstrating MULTIPLE CHOICE (with A, B, C, D options):
        **Q1:** What does the text compare science to?
        A. A mountain
        B. A star
        C. A giant jigsaw puzzle
        D. A flower
        **Answer:** A giant jigsaw puzzle
        **Explanation:** The text directly compares science to a giant and unending jigsaw puzzle where every discovery adds another piece.

        Expected JSON output for multiple choice (Answer 'A giant jigsaw puzzle' is Option C = index 2):
        [
            {
                "question": "What does the text compare science to?",
                "options": ["A mountain", "A star", "A giant jigsaw puzzle", "A flower"],
                "correctAnswer": 2,
                "explanation": "The text directly compares science to a giant and unending jigsaw puzzle where every discovery adds another piece."
            }
        ]

        Example input demonstrating OPEN-ENDED question (no A, B, C, D options):
        **Q2:** Explain in your own words what photosynthesis means.
        **Sample Answer:** Photosynthesis is the process by which plants make their own food using sunlight, water, and carbon dioxide.

        Expected JSON output for open-ended question:
        [
            {
                "question": "Explain in your own words what photosynthesis means.",
                "options": [],
                "correctAnswer": -1,
                "explanation": "Photosynthesis is the process by which plants make their own food using sunlight, water, and carbon dioxide."
            }
        ]

        Assessment text to parse:
        \(assessmentString)
        """
        
        do {
            let session = LanguageModelSession(instructions: instructions)
            
            let response = try await session.respond(
                to: prompt,
                generating: QuizJSONResponse.self
            )
            
            print("[DEBUG][QuizParser] Foundation Models successful.")
            // Map the AI-decoded models to your final internal model (QuizQuestion)
            return response.content.questions.map { $0.toQuizQuestion() }
            
        } catch {
            print("[DEBUG][QuizParser] Foundation Models parsing failed: \(error)")
            // Log error details for debugging
            print("[DEBUG][QuizParser] Error type: \(type(of: error))")
            return nil
        }
    }
    
}
// MARK: - Foundation Models Data Structures
@Generable(description: "A structured quiz question with options, correct answer, and explanation")
struct QuizQuestionAI {
    @Guide(description: "The question text")
    var question: String
    
    @Guide(description: "Multiple choice options (empty array for open-ended questions)")
    var options: [String]
    
    @Guide(description: "Index of correct answer (0-based, -1 for open-ended questions)", .range(-1...10))
    var correctAnswer: Int
    
    @Guide(description: "Optional explanation for the answer")
    var explanation: String?
    
    func toQuizQuestion() -> QuizQuestion {
        QuizQuestion(
            question: question,
            options: options,
            correctAnswer: correctAnswer,
            explanation: explanation
        )
    }
}

@Generable(description: "An array of parsed quiz questions")
struct QuizJSONResponse {
    @Guide(description: "Array of quiz questions", .count(1...20))
    var questions: [QuizQuestionAI]
}

// MARK: - Quiz Main View
struct QuizView: View {
    let topic: SproutTopicWithCompletion
    @Binding var isPresented: Bool
    @StateObject private var quizVM = QuizViewModel()
    @State private var showTextMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                if showTextMode {
                    QuizTextView(topic: topic, quizVM: quizVM)
                } else if quizVM.questions.isEmpty {
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !quizVM.questions.isEmpty && !quizVM.isQuizCompleted && !showTextMode {
                            Text("\(quizVM.currentQuestionIndex + 1)/\(quizVM.totalQuestions)")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        
                        Button(showTextMode ? "Quiz Mode" : "Text Mode") {
                            showTextMode.toggle()
                        }
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.2))
                        )
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
        
        Task {
            await quizVM.loadQuestions(from: assessmentQuestions)
        }
    }
}

// MARK: - Quiz Text View
struct QuizTextView: View {
    let topic: SproutTopicWithCompletion
    @ObservedObject var quizVM: QuizViewModel
    @State private var showRawText = true
    
    // Helper function to get option letter for any index
    private func optionLetter(for index: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        guard index < letters.count else { return "\(index + 1)" }
        return String(letters[letters.index(letters.startIndex, offsetBy: index)])
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Toggle between raw text and parsed questions
                toggleSection
                
                if showRawText {
                    rawTextSection
                } else {
                    parsedQuestionsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
    
    private var toggleSection: some View {
        HStack {
            Button(action: { showRawText = true }) {
                Text("Raw Text")
                    .font(.caption)
                    .fontWeight(showRawText ? .semibold : .regular)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(showRawText ? AppTheme.secondary : Color.white.opacity(0.2))
                    )
            }
            
            Button(action: { showRawText = false }) {
                Text("Parsed Questions (\(quizVM.questions.count))")
                    .font(.caption)
                    .fontWeight(!showRawText ? .semibold : .regular)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(!showRawText ? AppTheme.secondary : Color.white.opacity(0.2))
                    )
            }
            
            Spacer()
        }
    }
    
    private var rawTextSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(AppTheme.secondary)
                    .font(.title2)
                
                Text("Assessment Questions (Raw Text)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if let assessmentQuestions = topic.aiContent?.assessmentQuestions {
                Text(assessmentQuestions)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .textSelection(.enabled)
            } else {
                Text("No assessment questions available")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var parsedQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(quizVM.questions.indices, id: \.self) { index in
                questionCard(question: quizVM.questions[index], number: index + 1)
            }
        }
    }
    
    private func questionCard(question: QuizQuestion, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question header
            HStack {
                Text("Question \(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.secondary)
                
                Spacer()
                
                if question.options.isEmpty {
                    Text("Open Answer")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.secondary.opacity(0.2))
                        )
                } else {
                    Text("Answer: \(optionLetter(for: question.correctAnswer))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.success.opacity(0.2))
                        )
                }
            }
            
            // Question text
            Text(question.question)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Options or Open Answer indicator
            if question.options.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                            .foregroundColor(AppTheme.secondary)
                            .font(.caption)
                        
                        Text("Open-ended question - requires written response")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.secondary.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(question.options.indices, id: \.self) { optionIndex in
                        HStack(spacing: 12) {
                            Text(optionLetter(for: optionIndex))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(optionIndex == question.correctAnswer ? AppTheme.success : .white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(optionIndex == question.correctAnswer ? AppTheme.success.opacity(0.3) : Color.white.opacity(0.2))
                                        .overlay(
                                            Circle()
                                                .stroke(optionIndex == question.correctAnswer ? AppTheme.success : Color.white.opacity(0.4), lineWidth: 1)
                                        )
                                )
                            
                            Text(question.options[optionIndex])
                                .font(.body)
                                .foregroundColor(optionIndex == question.correctAnswer ? AppTheme.success : .white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            if optionIndex == question.correctAnswer {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.success)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            
            // Explanation (if available)
            if let explanation = question.explanation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(AppTheme.secondary)
                            .font(.caption)
                        
                        Text("Explanation")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.secondary)
                    }
                    
                    Text(explanation)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.secondary.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
