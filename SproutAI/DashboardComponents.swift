//
//  DashboardComponents.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.secondary))
                .scaleEffect(1.2)
            Text("Loading subjects...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: (() -> Void)?
    
    init(message: String, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.9))
            
            Text("Something went wrong")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.secondary)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient)
    }
}

// MARK: - Class Chip
struct ClassChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline).bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? AppTheme.secondary : Color.white.opacity(0.15))
                .foregroundColor(selected ? .white : .white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.25), lineWidth: selected ? 0 : 1))
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.9))
            Text("No Subjects Available")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("No subjects have been assigned to your child's class yet.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Subject Card View
struct SubjectCardView: View {
    let subject: SproutSubjectWithProgress
    @Binding var expandedTopics: Set<String>
    @Binding var selectedTopic: SproutTopicWithCompletion?
    
    @Binding var videoURLToPlay: String?
    @Binding var showVideoPlayer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.primary)

                if let className = subject.className {
                    Text(className)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.secondary)
                }
                if let description = subject.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary.opacity(0.8))
                        .padding(.top, 8)
                }
            }

            if let totalTopics = subject.totalTopics {
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.primary)
                        Spacer()
                        Text("\(subject.completedTopics ?? 0) / \(totalTopics) topics")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.secondary)
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.secondary.opacity(0.2))
                                .frame(height: 8)
                                .cornerRadius(4)
                            let progress = CGFloat(subject.completedTopics ?? 0) / CGFloat(max(totalTopics, 1))
                            Rectangle()
                                .fill(AppTheme.secondary)
                                .frame(width: geometry.size.width * progress, height: 8)
                                .cornerRadius(4)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 16)
            }

            if let completed = subject.completedTopicsList, !completed.isEmpty {
                VStack(spacing: 8) {
                    ForEach(completed) { topic in
                        TopicAccordionView(
                            topic: topic,
                            isExpanded: expandedTopics.contains(topic.id),
                            onToggle: { toggleTopic(topic.id) },
                            onQuizTap: {
                                selectedTopic = topic
                            },
                            onVideoTap: { url in
                                print("[DEBUG][SubjectCardView] Video URL received: '\(url)'")
                                print("[DEBUG][SubjectCardView] URL is empty: \(url.isEmpty)")
                                
                                // Validate and set the URL synchronously
                                let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmedURL.isEmpty else {
                                    print("[DEBUG][SubjectCardView] ERROR: Empty video URL after trimming")
                                    return
                                }
                                
                                guard URL(string: trimmedURL) != nil else {
                                    print("[DEBUG][SubjectCardView] ERROR: Invalid video URL format: '\(trimmedURL)'")
                                    return
                                }
                                
                                print("[DEBUG][SubjectCardView] Valid URL found, setting state")
                                // Set both values in the same state update with a small delay
                                DispatchQueue.main.async {
                                    print("[DEBUG][SubjectCardView] Setting parent state - videoURLToPlay: '\(trimmedURL)'")
                                    videoURLToPlay = trimmedURL
                                    
                                    // Add a small delay before showing the sheet
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showVideoPlayer = true
                                        print("[DEBUG][SubjectCardView] Parent state set - videoURLToPlay: '\(videoURLToPlay ?? "nil")', showVideoPlayer: \(showVideoPlayer)")
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.95)).shadow(color: AppTheme.primary.opacity(0.15), radius: 8, x: 0, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.secondary.opacity(0.2), lineWidth: 1))
    }

    private func toggleTopic(_ id: String) {
        if expandedTopics.contains(id) { 
            expandedTopics.remove(id) 
        } else { 
            expandedTopics.insert(id) 
        }
    }
}

// MARK: - Topic Accordion View
struct TopicAccordionView: View {
    let topic: SproutTopicWithCompletion
    let isExpanded: Bool
    let onToggle: () -> Void
    let onQuizTap: () -> Void
    let onVideoTap: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerButton
            
            if isExpanded {
                expandedContent
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.success.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private var headerButton: some View {
        Button(action: onToggle) {
            headerButtonContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var headerButtonContent: some View {
        HStack(spacing: 12) {
            checkmarkIcon
            topicNameSection
            chevronIcon
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(isExpanded ? 0.08 : 1.0))
    }
    
    private var checkmarkIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(AppTheme.success)
            .font(.system(size: 16))
    }
    
    private var topicNameSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(topic.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
        }
    }
    
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(AppTheme.primary)
            .font(.system(size: 14))
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private var expandedContent: some View {
        VStack(spacing: 16) {
            Spacer()
            videosSection
            quizSection
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(AppTheme.success.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(AppTheme.success.opacity(0.2))
                .frame(height: 1),
            alignment: .top
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var videosSection: some View {
        Group {
            if let videos = topic.aiContent?.videos, !videos.isEmpty {
                let _ = print("[DEBUG][TopicAccordionView] Topic '\(topic.name)' has \(videos.count) videos")
                ForEach(videos.enumerated().map { (index, video) in 
                    let _ = print("[DEBUG][TopicAccordionView] Video \(index): title='\(video.title)', url='\(video.url)' (length: \(video.url.count))")
                    return video 
                }) { video in
                    VStack(alignment: .leading, spacing: 12) {
                        VideoLinkView(video: video) {
                            print("[DEBUG][TopicAccordionView] Video tapped: '\(video.title)' with URL: '\(video.url)'")
                            
                            // TEMPORARY: Add a test URL if the video URL is empty
                            let testURL = video.url.isEmpty ? "https://www.youtube.com/watch?v=dQw4w9WgXcQ" : video.url
                            
                            // Validate the URL before passing it
                            let trimmedURL = testURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedURL.isEmpty && URL(string: trimmedURL) != nil {
                                print("[DEBUG][TopicAccordionView] Valid URL, calling onVideoTap with: '\(trimmedURL)'")
                                onVideoTap(trimmedURL)
                            } else {
                                print("[DEBUG][TopicAccordionView] Invalid video URL: '\(testURL)'")
                                // Still call onVideoTap with the original URL so the parent can handle the error
                                onVideoTap(testURL)
                            }
                        }
                    }
                }
            } else {
                let _ = print("[DEBUG][TopicAccordionView] Topic '\(topic.name)' has no videos")
                noVideosMessage
            }
        }
    }
    
    private var noVideosMessage: some View {
        Text("No videos available")
            .font(.caption)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
    
    private var quizSection: some View {
        Group {
            if let assessmentQuestions = topic.aiContent?.assessmentQuestions {
                let _ = print("[DEBUG][TopicAccordionView] Topic '\(topic.name)' - assessmentQuestions: '\(assessmentQuestions.prefix(100))'")
                let trimmedQuestions = assessmentQuestions.trimmingCharacters(in: .whitespacesAndNewlines)
                let _ = print("[DEBUG][TopicAccordionView] Topic '\(topic.name)' - trimmed length: \(trimmedQuestions.count)")
                
                if !trimmedQuestions.isEmpty {
                    quizButton
                } else {
                    let _ = print("[DEBUG][TopicAccordionView] Topic '\(topic.name)' - Quiz button hidden: questions are empty after trimming")
                    EmptyView()
                }
            } else {
                let _ = print("[DEBUG][TopicAccordionView] Topic '\(topic.name)' - Quiz button hidden: assessmentQuestions is nil")
                EmptyView()
            }
        }
    }
    
    private var quizButton: some View {
        Button(action: onQuizTap) {
            quizButtonContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var quizButtonContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "target")
            Text("Take Quiz")
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(quizButtonGradient)
        .cornerRadius(8)
    }
    
    private var quizButtonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [AppTheme.primary, AppTheme.primary.opacity(0.8)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Video Link View
struct VideoLinkView: View {
    let video: SproutVideo
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            videoLinkContent
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = pressing }
        }, perform: {})
    }
    
    private var videoLinkContent: some View {
        HStack(spacing: 12) {
            playButtonIcon
            videoInfoSection
            Spacer()
            externalLinkIcon
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var playButtonIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.secondary.opacity(0.2))
                .frame(width: 32, height: 32)
            Image(systemName: "play.fill")
                .foregroundColor(AppTheme.secondary)
                .font(.system(size: 14))
        }
    }
    
    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(video.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.primary)
                .lineLimit(2)
            
            if let duration = video.duration {
                Text(duration)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text("Tap to play video")
                .font(.caption2)
                .foregroundColor(AppTheme.secondary)
        }
    }
    
    private var externalLinkIcon: some View {
        Image(systemName: "play.circle")
            .foregroundColor(AppTheme.secondary)
            .font(.caption)
    }
}
