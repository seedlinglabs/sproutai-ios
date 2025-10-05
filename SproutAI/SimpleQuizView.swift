//
//  SimpleQuizView.swift
//  SproutAI
//
//  Created by Assistant on 05/10/25.
//

import SwiftUI

// MARK: - Simple Quiz View for Text Display
struct SimpleQuizView: View {
    let topic: SproutTopicWithCompletion
    @Binding var isPresented: Bool
    @State private var assessmentText: String = ""
    @State private var parsedQuestions: [QuizQuestion] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if assessmentText.isEmpty {
                            // Loading or no content state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                
                                Text("Loading assessment questions...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else if parsedQuestions.isEmpty {
                            // Raw text display
                            rawTextSection
                        } else {
                            // Parsed questions display
                            parsedQuestionsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(topic.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(parsedQuestions.isEmpty ? "Parse Questions" : "Show Raw Text") {
                        if parsedQuestions.isEmpty {
                            parseQuestions()
                        } else {
                            parsedQuestions = []
                        }
                    }
                    .foregroundColor(.white)
                    .font(.caption)
                }
            }
            .onAppear {
                loadAssessmentText()
            }
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
            
            Text(assessmentText)
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
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(AppTheme.secondary)
                    .font(.title2)
                
                Text("Parsed Questions (\(parsedQuestions.count))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ForEach(parsedQuestions.indices, id: \.self) { index in
                questionCard(question: parsedQuestions[index], number: index + 1)
            }
        }
    }
    
    // Helper function to get option letter for any index
    private func optionLetter(for index: Int) -> String {
        guard index >= 0 else { return "N/A" }
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        guard index < letters.count else { return "\(index + 1)" }
        return String(letters[letters.index(letters.startIndex, offsetBy: index)])
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
                
                if question.correctAnswer >= 0 {
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
                } else {
                    Text("Open-ended")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.secondary.opacity(0.2))
                        )
                }
            }
            
            // Question text
            Text(question.question)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Options
            if !question.options.isEmpty {
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
    
    private func loadAssessmentText() {
        guard let assessmentQuestions = topic.aiContent?.assessmentQuestions,
              !assessmentQuestions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            assessmentText = "No assessment questions available for this topic."
            return
        }
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            assessmentText = assessmentQuestions
        }
    }
    
    private func parseQuestions() {
        Task {
            let questions = await QuizParser.parse(assessmentText)
            await MainActor.run {
                parsedQuestions = questions
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SimpleQuizView(
        topic: SproutTopicWithCompletion(
            id: "1",
            name: "Sample Topic",
            description: "A sample topic for testing",
            subjectId: "sub1",
            schoolId: "school1",
            classId: "class1",
            createdAt: "2024-01-01",
            updatedAt: "2024-01-01",
            aiContent: SproutAIContent(
                summary: "Sample summary",
                videos: nil,
                assessmentQuestions: """
                1. What is the capital of France?
                A) London
                B) Berlin
                C) Paris
                D) Madrid
                Answer: C
                
                2. Which planet is closest to the Sun?
                A) Venus
                B) Mercury
                C) Earth
                D) Mars
                Answer: B
                """
            ),
            completedAt: nil
        ),
        isPresented: .constant(true)
    )
}