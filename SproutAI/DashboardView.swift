//
//  DashboardView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI
import Combine

// MARK: - Dashboard View Model
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var subjects: [SproutSubjectWithProgress] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let academicRecordsService = AcademicRecordsService()
    private let topicsService = TopicsService()
    private var loadingTask: Task<Void, Never>?

    func loadSubjects(for user: Parent) async {
        print("[DEBUG][DashboardVM] Loading subjects for user: \(user.userId), classes: \(user.classAccess)")
        
        loadingTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        loadingTask = Task {
            do {
                let academicYear = "2025-26"
                
                let records = try await withThrowingTaskGroup(of: [SproutAcademicRecord].self) { group in
                    group.addTask {
                        try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds timeout
                        throw URLError(.timedOut)
                    }
                    
                    group.addTask {
                        return try await self.academicRecordsService.getRecordsForParent(
                            schoolId: user.schoolId,
                            academicYear: academicYear,
                            classAccess: user.classAccess
                        )
                    }
                    
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
                
                if Task.isCancelled { return }
                
                print("[DEBUG][DashboardVM] Retrieved \(records.count) academic records")
                
                let subjects = try await buildSubjectsWithProgress(records: records, user: user)
                
                if Task.isCancelled { return }
                
                self.subjects = subjects
                self.isLoading = false
                
                print("[DEBUG][DashboardVM] Successfully loaded \(subjects.count) subjects")
                
            } catch {
                if Task.isCancelled { return }
                
                print("[DEBUG][DashboardVM] Error loading subjects: \(error)")
                
                let message: String
                if error is CancellationError {
                    message = "Loading was cancelled"
                } else if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        message = "Request timed out. Please check your internet connection and try again."
                    case .notConnectedToInternet:
                        message = "No internet connection. Please check your network and try again."
                    case .cannotFindHost, .cannotConnectToHost:
                        message = "Cannot connect to server. Please try again later."
                    default:
                        message = "Network error: \(urlError.localizedDescription)"
                    }
                } else {
                    message = "Failed to load academic records. Please try again."
                }
                
                self.errorMessage = message
                self.isLoading = false
            }
        }
    }
    
    func retry(for user: Parent) {
        Task {
            await loadSubjects(for: user)
        }
    }

    private func buildSubjectsWithProgress(records: [SproutAcademicRecord], user: Parent) async throws -> [SproutSubjectWithProgress] {
        print("[DEBUG][DashboardVM] Building subjects from \(records.count) records")
        
        if records.isEmpty {
            print("[DEBUG][DashboardVM] No records to process")
            return []
        }
        
        let grouped = Dictionary(grouping: records, by: { $0.subjectId })
        var result: [SproutSubjectWithProgress] = []

        await withTaskGroup(of: SproutSubjectWithProgress?.self) { group in
            for (subjectId, items) in grouped {
                group.addTask {
                    if Task.isCancelled { return nil }
                    
                    print("[DEBUG][DashboardVM] Processing subjectId=\(subjectId) with \(items.count) records")
                    
                    // First, get all topics to know the total count (lightweight call)
                    let allTopics: [SproutTopic]
                    do {
                        allTopics = try await self.topicsService.getTopicsLightweight(subjectId: subjectId)
                        print("[DEBUG][DashboardVM] Fetched \(allTopics.count) total topics (lightweight) for subjectId=\(subjectId)")
                    } catch {
                        print("[DEBUG][DashboardVM] Failed to fetch lightweight topics for subjectId=\(subjectId): \(error)")
                        allTopics = []
                    }
                    
                    if Task.isCancelled { return nil }
                    
                    // Identify completed topic IDs from academic records
                    let completedRecords = items.filter { $0.status == "completed" }
                    let completedTopicIds = Set(completedRecords.map { $0.topicId })
                    
                    print("[DEBUG][DashboardVM] Found \(completedTopicIds.count) completed topic IDs for subjectId=\(subjectId)")
                    
                    // Only fetch detailed information for completed topics
                    var completedTopics: [SproutTopicWithCompletion] = []
                    
                    await withTaskGroup(of: SproutTopicWithCompletion?.self) { topicGroup in
                        for topicId in completedTopicIds {
                            topicGroup.addTask {
                                if Task.isCancelled { return nil }
                                
                                do {
                                    if let detailedTopic = try await self.topicsService.getTopic(id: topicId) {
                                        print("[DEBUG][DashboardVM] Fetched detailed topic: \(detailedTopic.name)")
                                        
                                        return SproutTopicWithCompletion(
                                            id: detailedTopic.id,
                                            name: detailedTopic.name,
                                            description: detailedTopic.description,
                                            subjectId: detailedTopic.subjectId,
                                            schoolId: detailedTopic.schoolId,
                                            classId: detailedTopic.classId,
                                            createdAt: detailedTopic.createdAt,
                                            updatedAt: detailedTopic.updatedAt,
                                            aiContent: detailedTopic.aiContent,
                                            completedAt: completedRecords.first(where: { $0.topicId == topicId })?.updatedAt
                                        )
                                    } else {
                                        print("[DEBUG][DashboardVM] Topic not found: \(topicId)")
                                        return nil
                                    }
                                } catch {
                                    print("[DEBUG][DashboardVM] Failed to fetch detailed topic \(topicId): \(error)")
                                    return nil
                                }
                            }
                        }
                        
                        for await completedTopic in topicGroup {
                            if let topic = completedTopic {
                                completedTopics.append(topic)
                            }
                        }
                    }
                    
                    // Sort completed topics by name for consistent display
                    completedTopics.sort { $0.name < $1.name }
                    
                    print("[DEBUG][DashboardVM] Successfully loaded \(completedTopics.count) completed topics with full details for subjectId=\(subjectId)")

                    let progress = SproutSubjectWithProgress(
                        id: subjectId,
                        name: items.first?.subjectName ?? "Subject",
                        description: nil,
                        classId: items.first?.grade ?? "",
                        schoolId: user.schoolId,
                        schoolName: nil,
                        className: items.first.map { "\($0.grade)\($0.section)" },
                        createdAt: items.first?.createdAt ?? "",
                        updatedAt: items.first?.updatedAt ?? "",
                        totalTopics: allTopics.count > 0 ? allTopics.count : nil,
                        completedTopics: completedTopics.count,
                        completedTopicsList: completedTopics.isEmpty ? nil : completedTopics
                    )
                    
                    print("[DEBUG][DashboardVM] Created subject \(progress.name) with total=\(progress.totalTopics ?? 0), completed=\(progress.completedTopics ?? 0)")
                    return progress
                }
            }
            
            for await subjectProgress in group {
                if let progress = subjectProgress {
                    result.append(progress)
                }
            }
        }
        
        let sortedResult = result.sorted { $0.name < $1.name }
        print("[DEBUG][DashboardVM] Built \(sortedResult.count) subjects with progress")
        return sortedResult
    }
    
    deinit {
        loadingTask?.cancel()
    }
}

// MARK: - Dashboard Main View
struct DashboardView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var dashboardVM = DashboardViewModel()
    @State private var expandedTopics: Set<String> = []
    @State private var selectedTopic: SproutTopicWithCompletion?
    
    @State private var showVideoPlayer = false {
        didSet {
            print("[DEBUG][DashboardView] showVideoPlayer changed to: \(showVideoPlayer)")
        }
    }
    @State private var videoURLToPlay: String? = nil {
        didSet {
            print("[DEBUG][DashboardView] videoURLToPlay changed to: '\(videoURLToPlay ?? "nil")'")
        }
    }
    
    @State private var selectedClass: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            header
            
            // Content
            if dashboardVM.isLoading {
                LoadingView()
            } else if let error = dashboardVM.errorMessage {
                ErrorView(message: error) {
                    if let user = authService.parent {
                        dashboardVM.retry(for: user)
                    }
                }
            } else {
                GeometryReader { geo in
                    let isCompact = geo.size.width < 700
                    let columns: [GridItem] = isCompact ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Class filter chips
                            if let classes = authService.parent?.classAccess, !classes.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ClassChip(title: "All", selected: selectedClass == nil) { 
                                            withAnimation(.easeInOut) { selectedClass = nil } 
                                        }
                                        ForEach(classes, id: \.self) { cls in
                                            ClassChip(title: cls, selected: selectedClass == cls) { 
                                                withAnimation(.easeInOut) { selectedClass = cls } 
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            // Subjects grid or empty state
                            if filteredSubjects.isEmpty {
                                EmptyStateView()
                                    .padding(.horizontal, 16)
                            } else {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(filteredSubjects) { subject in
                                        SubjectCardView(
                                            subject: subject,
                                            expandedTopics: $expandedTopics,
                                            selectedTopic: $selectedTopic,
                                            videoURLToPlay: $videoURLToPlay,
                                            showVideoPlayer: $showVideoPlayer
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                    .background(AppTheme.backgroundGradient)
                    .refreshable {
                        if let user = authService.parent {
                            await dashboardVM.loadSubjects(for: user)
                        }
                    }
                }
            }
        }
        .onAppear {
            if let user = authService.parent {
                Task { await dashboardVM.loadSubjects(for: user) }
            }
        }
        .sheet(item: $selectedTopic) { topic in
            QuizView(topic: topic, isPresented: Binding(
                get: { selectedTopic != nil },
                set: { if !$0 { selectedTopic = nil } }
            ))
            .environmentObject(authService)
        }
        .sheet(isPresented: $showVideoPlayer) {
            let _ = print("[DEBUG][DashboardView] Sheet presented. videoURLToPlay: '\(videoURLToPlay ?? "nil")'")
            if let videoURL = videoURLToPlay, !videoURL.isEmpty {
                let _ = print("[DEBUG][DashboardView] Showing VideoPlayerView with URL: '\(videoURL)'")
                VideoPlayerView(urlString: videoURL)
            } else {
                let _ = print("[DEBUG][DashboardView] Showing error view - no valid URL")
                // Fallback view for invalid URLs
                NavigationView {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 64))
                            .foregroundColor(.red)
                        
                        Text("No video URL available")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("The video URL is missing or invalid.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Add debug information
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Debug Info:")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("videoURLToPlay: '\(videoURLToPlay ?? "nil")'")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("isEmpty: \(videoURLToPlay?.isEmpty ?? true)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                    .navigationTitle("Video Error")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showVideoPlayer = false
                                videoURLToPlay = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredSubjects: [SproutSubjectWithProgress] {
        guard let selectedClass = selectedClass, !selectedClass.isEmpty else { return dashboardVM.subjects }
        return dashboardVM.subjects.filter { $0.className == selectedClass }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.primary)
                .frame(height: 0)
                .ignoresSafeArea(edges: .top)
            
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 12) {
                    Image("SeedlingLabsLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                    
                    if let user = authService.parent {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sprout AI")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(getSchoolDisplayName(schoolId: user.schoolId))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { /* TODO: Home action */ }) {
                        Image(systemName: "house.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                    
                    Button(action: { authService.logout() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppTheme.primary, AppTheme.primary.opacity(0.9)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
        }
    }
    
    private func getSchoolDisplayName(schoolId: String) -> String {
        switch schoolId {
        case "content-development-school":
            return "Content Development School"
        case "sri-vidyaniketan-international-school-icse":
            return "Sri Vidyaniketan International School (ICSE)"
        case "sri-vidyaniketan-public-school-cbse":
            return "Sri Vidyaniketan Public School (CBSE)"
        default:
            return schoolId.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}