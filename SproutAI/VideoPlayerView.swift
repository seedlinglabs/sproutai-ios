//
//  VideoPlayerView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI

struct VideoPlayerView: View {
    let urlString: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let url = URL(string: urlString) {
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(AppTheme.primary)
                        
                        Text("Video Player")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.primary)
                        
                        Text("URL: \(urlString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            openVideoExternally(url: url)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                Text("Open in Browser")
                            }
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            openInYouTubeApp(url: url)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.tv")
                                Text("Open in YouTube App")
                            }
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.secondary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 64))
                            .foregroundColor(.red)
                        
                        Text("Invalid video URL")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("The video URL could not be opened.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func openVideoExternally(url: URL) {
        UIApplication.shared.open(url)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func openInYouTubeApp(url: URL) {
        if let youtubeAppURL = convertToYouTubeAppURL(from: url),
           UIApplication.shared.canOpenURL(youtubeAppURL) {
            UIApplication.shared.open(youtubeAppURL)
            presentationMode.wrappedValue.dismiss()
        } else {
            // Fallback to browser if YouTube app is not available
            openVideoExternally(url: url)
        }
    }
    
    private func convertToYouTubeAppURL(from url: URL) -> URL? {
        let host = url.host ?? ""
        
        // Handle youtu.be short links
        if host.contains("youtu.be") {
            let videoId = url.lastPathComponent
            return URL(string: "youtube://watch?v=\(videoId)")
        }
        
        // Handle regular YouTube URLs
        if host.contains("youtube.com") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return URL(string: "youtube://watch?v=\(videoId)")
            }
            
            // Handle /shorts/, /embed/, or /v/ paths
            let path = url.path
            if path.contains("/shorts/") || path.contains("/embed/") || path.contains("/v/") {
                let videoId = url.lastPathComponent
                return URL(string: "youtube://watch?v=\(videoId)")
            }
        }
        
        return nil
    }
}