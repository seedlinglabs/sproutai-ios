//
//  SampleContentProvider.swift
//  SproutAI
//
//  Created by Codex on 04/11/25.
//

import Foundation

enum SampleContentProvider {
    private static let sampleLibrary: [String: [SproutVideo]] = [
        "math": [
            SproutVideo(
                title: "Fractions for Kids | Homeschool Pop",
                url: "https://www.youtube.com/watch?v=wfYbgdo8e-8",
                duration: "07:12",
                thumbnail: nil
            ),
            SproutVideo(
                title: "Geometry Basics: Shapes, Angles & Lines",
                url: "https://www.youtube.com/watch?v=1W5aYi3lkho",
                duration: "06:14",
                thumbnail: nil
            )
        ],
        "science": [
            SproutVideo(
                title: "The Water Cycle | TED-Ed",
                url: "https://www.youtube.com/watch?v=IO9tT186mZw",
                duration: "04:29",
                thumbnail: nil
            ),
            SproutVideo(
                title: "What Is Photosynthesis? | SciShow Kids",
                url: "https://www.youtube.com/watch?v=eo5XndJaz-Y",
                duration: "04:23",
                thumbnail: nil
            )
        ],
        "english": [
            SproutVideo(
                title: "Parts of Speech for Kids | Scratch Garden",
                url: "https://www.youtube.com/watch?v=E6Ac1lYkKGI",
                duration: "04:24",
                thumbnail: nil
            )
        ],
        "computer": [
            SproutVideo(
                title: "Coding for Kids: What Is Coding?",
                url: "https://www.youtube.com/watch?v=q7DYc8f7V1g",
                duration: "05:01",
                thumbnail: nil
            )
        ]
    ]
    
    private static let defaultSamples: [SproutVideo] = [
        SproutVideo(
            title: "Learning Is Fun | Cosmic Kids",
            url: "https://www.youtube.com/watch?v=5if4cjO5nxo",
            duration: "04:41",
            thumbnail: nil
        )
    ]
    
    static func videos(for topic: SproutTopicWithCompletion) -> [SproutVideo] {
        let subjectKey = topic.subjectId.lowercased()
        let topicKey = topic.name.lowercased()
        
        if let subjectVideos = sampleLibrary.first(where: { subjectKey.contains($0.key) }) {
            return subjectVideos.value
        }
        
        if let topicVideos = sampleLibrary.first(where: { topicKey.contains($0.key) }) {
            return topicVideos.value
        }
        
        return defaultSamples
    }
}
