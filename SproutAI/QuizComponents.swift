//
//  QuizComponents.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI

// MARK: - Quiz Question View
struct QuizQuestionView: View {
    @ObservedObject var quizVM: QuizViewModel
    
    // Helper function to get option letter for any index
    private func optionLetter(for index: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        guard index < letters.count else { return "\(index + 1)" }
        return String(letters[letters.index(letters.startIndex, offsetBy: index)])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * quizVM.progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: quizVM.progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
            
            ScrollView {
                VStack(spacing: 24) {
                    if let currentQuestion = quizVM.currentQuestion {
                        // Question
                        questionSection(currentQuestion)
                        
                        // Options
                        optionsSection(currentQuestion)
                        
                        // Action buttons
                        actionButtons
                        
                        // Explanation (if showing)
                        if quizVM.showExplanation, let explanation = currentQuestion.explanation {
                            explanationSection(explanation)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 32)
            }
        }
    }
    
    private func questionSection(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(AppTheme.secondary)
                    .font(.title2)
                
                Text("Question \(quizVM.currentQuestionIndex + 1)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(question.question)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func optionsSection(_ question: QuizQuestion) -> some View {
        Group {
            if question.options.isEmpty {
                // Non-Multiple Choice: Show TextEditor for short/long answer
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(AppTheme.secondary)
                            .font(.title2)
                        
                        Text("Reference Answer")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Not Scored")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppTheme.secondary.opacity(0.2))
                            )
                    }
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $quizVM.shortAnswerText)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color.clear)
                            .foregroundColor(.white)
                            .font(.body)
                            .disabled(true) // Make read-only for reference answers
                            .scrollContentBackground(.hidden)
                        
                        if quizVM.shortAnswerText.isEmpty && !quizVM.showResult {
                            Text("Sample answer will appear here...")
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Show submitted text during results
                    if quizVM.showResult, let result = quizVM.results.last, let submittedText = result.submittedText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your submitted answer:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.secondary)
                            
                            Text(submittedText)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppTheme.secondary.opacity(0.15))
                                )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                // Multiple Choice: Show existing options
                VStack(spacing: 12) {
                    ForEach(question.options.indices, id: \.self) { index in
                        optionButton(option: question.options[index], index: index, question: question)
                    }
                }
            }
        }
    }
    
    private func optionButton(option: String, index: Int, question: QuizQuestion) -> some View {
        Button(action: {
            if !quizVM.showResult {
                quizVM.selectAnswer(index)
            }
        }) {
            HStack(spacing: 16) {
                // Option letter
                Text(optionLetter(for: index))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(optionTextColor(index: index, question: question))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(optionCircleColor(index: index, question: question))
                            .overlay(
                                Circle()
                                    .stroke(optionBorderColor(index: index, question: question), lineWidth: 2)
                            )
                    )
                
                // Option text
                Text(option)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(optionTextColor(index: index, question: question))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Result icon
                if quizVM.showResult {
                    if index == question.correctAnswer {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    } else if index == quizVM.selectedAnswer {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(optionBackgroundColor(index: index, question: question))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(optionBorderColor(index: index, question: question), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .disabled(quizVM.showResult)
        .scaleEffect(quizVM.selectedAnswer == index && !quizVM.showResult ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: quizVM.selectedAnswer)
    }
    
    private func optionBackgroundColor(index: Int, question: QuizQuestion) -> Color {
        if quizVM.showResult {
            if index == question.correctAnswer {
                return AppTheme.success.opacity(0.2)
            } else if index == quizVM.selectedAnswer && index != question.correctAnswer {
                return AppTheme.error.opacity(0.2)
            }
        } else if quizVM.selectedAnswer == index {
            return AppTheme.secondary.opacity(0.3)
        }
        return Color.white.opacity(0.1)
    }
    
    private func optionCircleColor(index: Int, question: QuizQuestion) -> Color {
        if quizVM.showResult {
            if index == question.correctAnswer {
                return AppTheme.success
            } else if index == quizVM.selectedAnswer && index != question.correctAnswer {
                return AppTheme.error
            }
        } else if quizVM.selectedAnswer == index {
            return AppTheme.secondary
        }
        return Color.white.opacity(0.2)
    }
    
    private func optionBorderColor(index: Int, question: QuizQuestion) -> Color {
        if quizVM.showResult {
            if index == question.correctAnswer {
                return AppTheme.success
            } else if index == quizVM.selectedAnswer && index != question.correctAnswer {
                return AppTheme.error
            }
        } else if quizVM.selectedAnswer == index {
            return AppTheme.secondary
        }
        return Color.white.opacity(0.3)
    }
    
    private func optionTextColor(index: Int, question: QuizQuestion) -> Color {
        if quizVM.showResult {
            if index == question.correctAnswer || (index == quizVM.selectedAnswer && index != question.correctAnswer) {
                return .white
            }
        } else if quizVM.selectedAnswer == index {
            return .white
        }
        return .white.opacity(0.9)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            if quizVM.showResult {
                Button("Next Question") {
                    quizVM.nextQuestion()
                }
                .foregroundColor(.white)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.secondary)
                .cornerRadius(12)
            } else {
                Button(submitButtonText) {
                    quizVM.submitAnswer()
                }
                .foregroundColor(.white)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isSubmitEnabled ? AppTheme.primary : AppTheme.primary.opacity(0.5))
                .cornerRadius(12)
                .disabled(!isSubmitEnabled)
            }
        }
        .padding(.top, 8)
    }
    
    // Computed property to determine if submit button should be enabled
    private var isSubmitEnabled: Bool {
        guard let currentQuestion = quizVM.currentQuestion else { return false }
        
        if currentQuestion.options.isEmpty {
            // Non-multiple choice: always enabled (just for viewing reference answer)
            return true
        } else {
            // Multiple choice: check if an answer is selected
            return quizVM.selectedAnswer != nil
        }
    }
    
    // Computed property to determine submit button text
    private var submitButtonText: String {
        guard let currentQuestion = quizVM.currentQuestion else { return "Submit" }
        
        if currentQuestion.options.isEmpty {
            return "Continue"
        } else {
            return "Submit Answer"
        }
    }
    
    private func explanationSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppTheme.secondary)
                    .font(.title2)
                
                Text("Explanation")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(explanation)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.secondary.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Quiz Results View
struct QuizResultsView: View {
    @ObservedObject var quizVM: QuizViewModel
    let topic: SproutTopicWithCompletion
    @Binding var isPresented: Bool
    
    // Helper function to get option letter for any index
    private func optionLetter(for index: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        guard index < letters.count else { return "\(index + 1)" }
        return String(letters[letters.index(letters.startIndex, offsetBy: index)])
    }
    
    private var scorePercentage: Double {
        guard quizVM.totalMultipleChoiceQuestions > 0 else { return 0 }
        return Double(quizVM.score) / Double(quizVM.totalMultipleChoiceQuestions)
    }
    
    private var scoreColor: Color {
        if scorePercentage >= 0.8 { return AppTheme.success }
        else if scorePercentage >= 0.6 { return AppTheme.secondary }
        else { return AppTheme.error }
    }
    
    private var performanceMessage: String {
        if scorePercentage >= 0.9 { return "Excellent work! 🌟" }
        else if scorePercentage >= 0.8 { return "Great job! 👏" }
        else if scorePercentage >= 0.7 { return "Good effort! 👍" }
        else if scorePercentage >= 0.6 { return "Keep practicing! 📚" }
        else { return "Review the material and try again! 💪" }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Score section
                scoreSection
                
                // Performance message
                messageSection
                
                // Detailed results
                detailedResultsSection
                
                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)
        }
    }
    
    private var scoreSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: scorePercentage)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: scorePercentage)
                
                VStack(spacing: 4) {
                    Text("\(quizVM.score)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("/ \(quizVM.totalMultipleChoiceQuestions)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Text("\(Int(scorePercentage * 100))%")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if quizVM.totalQuestions > quizVM.totalMultipleChoiceQuestions {
                Text("Multiple Choice Score")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(scoreColor.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var messageSection: some View {
        VStack(spacing: 8) {
            Text(performanceMessage)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            if scorePercentage < 0.7 {
                Text("Consider reviewing the topic materials before trying again.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var detailedResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.clipboard")
                    .foregroundColor(AppTheme.secondary)
                    .font(.title2)
                
                Text("Question Review")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            ForEach(quizVM.results.indices, id: \.self) { index in
                let result = quizVM.results[index]
                let question = quizVM.questions[index]
                
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(getResultCircleColor(for: result, question: question))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.question)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        HStack {
                            if question.options.isEmpty {
                                // Non-multiple choice: show it's informational
                                Text("Reference answer provided")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondary)
                                    .italic()
                            } else {
                                // Multiple choice: show selected option
                                Text("Your answer: \(optionLetter(for: result.selectedAnswer))")
                                    .font(.caption)
                                    .foregroundColor(result.isCorrect ? AppTheme.success : AppTheme.error)
                                
                                if !result.isCorrect {
                                    Text("• Correct: \(optionLetter(for: question.correctAnswer))")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.success)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: getResultIcon(for: result, question: question))
                        .foregroundColor(getResultColor(for: result, question: question))
                        .font(.title2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Try Again") {
                quizVM.resetQuiz()
            }
            .foregroundColor(.white)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.primary)
            .cornerRadius(12)
            
            Button("Done") {
                isPresented = false
            }
            .foregroundColor(.white)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.secondary)
            .cornerRadius(12)
        }
    }
    
    // Helper methods for result display
    private func getResultIcon(for result: QuizResult, question: QuizQuestion) -> String {
        if question.options.isEmpty {
            // Non-multiple choice: show document icon for submitted answer
            return "doc.text.fill"
        } else {
            // Multiple choice: show checkmark or x
            return result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
    }
    
    private func getResultColor(for result: QuizResult, question: QuizQuestion) -> Color {
        if question.options.isEmpty {
            // Non-multiple choice: use secondary color
            return AppTheme.secondary
        } else {
            // Multiple choice: use success/error color
            return result.isCorrect ? AppTheme.success : AppTheme.error
        }
    }
    
    private func getResultCircleColor(for result: QuizResult, question: QuizQuestion) -> Color {
        if question.options.isEmpty {
            // Non-multiple choice: use secondary color (answer submitted)
            return AppTheme.secondary
        } else {
            // Multiple choice: use success/error color
            return result.isCorrect ? AppTheme.success : AppTheme.error
        }
    }
}