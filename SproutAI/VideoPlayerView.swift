//
//  VideoPlayerView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI
import AVKit
import WebKit

struct VideoPlayerView: View {
    let urlString: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var isYouTubeLoading = false
    
    private var videoSource: VideoSource? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        return VideoSource(url: url)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let source = videoSource {
                    VideoRenderView(source: source, isYouTubeLoading: $isYouTubeLoading)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(16)
                        .padding(.top)
                        .onAppear {
                            if case .youTube = source {
                                isYouTubeLoading = true
                            }
                        }
                    
                    Text("Playing in-app: \(source.originalURL.absoluteString)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    invalidURLView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var invalidURLView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.error)
            
            Text("Unable to load video")
                .font(.headline)
                .foregroundColor(AppTheme.error)
            
            Text("The provided URL is missing or malformed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 48)
    }
}

// MARK: - Helper Views
private struct VideoRenderView: View {
    let source: VideoSource
    @Binding var isYouTubeLoading: Bool
    @State private var fallbackURL: URL?
    
    var body: some View {
        VStack {
            switch source {
            case .direct(let url):
                InlineVideoPlayer(url: url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipped()
            case .youTube(let originalURL, let videoId):
                ZStack {
                    YouTubeEmbedView(
                        videoId: videoId,
                        originalURL: originalURL,
                        isLoading: $isYouTubeLoading
                    ) { status in
                        switch status {
                        case .ready:
                            fallbackURL = nil
                        case .failed(let url):
                            fallbackURL = url
                        }
                    }
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipped()
                    
                    if isYouTubeLoading {
                        ProgressView("Loading video…")
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.secondary))
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    } else if let url = fallbackURL {
                        VStack(spacing: 12) {
                            Image(systemName: "play.rectangle.on.rectangle")
                                .font(.largeTitle)
                                .foregroundColor(AppTheme.secondary)
                            Text("This video can only be played on YouTube.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                            Link(destination: url) {
                                Label("Open in YouTube", systemImage: "safari")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.secondary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(14)
                    }
                }
                .onAppear {
                    fallbackURL = nil
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

private struct InlineVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

private struct YouTubeEmbedView: UIViewRepresentable {
    let videoId: String
    let originalURL: URL
    @Binding var isLoading: Bool
    let statusHandler: (VideoPlaybackStatus) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            isLoading: $isLoading,
            statusHandler: statusHandler,
            videoURL: originalURL
        )
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptEnabled = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.accessibilityIdentifier = videoId
        
        let html = Self.htmlTemplate(for: videoId)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard uiView.accessibilityIdentifier != videoId else { return }
        uiView.accessibilityIdentifier = videoId
        let html = Self.htmlTemplate(for: videoId)
        isLoading = true
        uiView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }
    
    private static func htmlTemplate(for videoId: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    background-color: #000000;
                    height: 100%;
                }
                .video-container {
                    position: absolute;
                    top: 0;
                    left: 0;
                    bottom: 0;
                    right: 0;
                }
                iframe {
                    width: 100%;
                    height: 100%;
                }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe src="https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1&controls=1"
                        frameborder="0"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                        allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate {
        private var isLoading: Binding<Bool>
        private let statusHandler: (VideoPlaybackStatus) -> Void
        private let fallbackURL: URL
        
        init(isLoading: Binding<Bool>, statusHandler: @escaping (VideoPlaybackStatus) -> Void, videoURL: URL) {
            self.isLoading = isLoading
            self.statusHandler = statusHandler
            self.fallbackURL = videoURL
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = false
                self.statusHandler(.ready)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = false
                self.statusHandler(.failed(self.fallbackURL))
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = false
                self.statusHandler(.failed(self.fallbackURL))
            }
        }
    }
}

private enum VideoPlaybackStatus {
    case ready
    case failed(URL)
}

// MARK: - Video Source
private enum VideoSource {
    case direct(URL)
    case youTube(original: URL, videoId: String)
    
    init?(url: URL) {
        if let videoId = VideoSource.videoId(from: url) {
            self = .youTube(original: url, videoId: videoId)
        } else {
            self = .direct(url)
        }
    }
    
    var originalURL: URL {
        switch self {
        case .direct(let url):
            return url
        case .youTube(let original, _):
            return original
        }
    }
    
    private static func videoId(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if host.contains("youtu.be") {
            return pathComponents.last
        }
        
        if host.contains("youtube.com") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let videoId = queryItems.first(where: { $0.name == "v" })?.value {
                return videoId
            }
            
            if let last = pathComponents.last,
               pathComponents.contains(where: { ["shorts", "embed", "v"].contains($0.lowercased()) }) {
                return last
            }
        }
        
        return nil
    }
}
