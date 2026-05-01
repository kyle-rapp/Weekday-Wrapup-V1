import Foundation

/// FILE: Models/TherapyResource.swift
/// Keyword-matched therapy resource links (lightweight, capped list).

struct TherapyResource: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let url: String
    let tags: [String]

    init(id: UUID = UUID(), title: String, url: String, tags: [String]) {
        self.id = id
        self.title = title
        self.url = url
        self.tags = tags
    }
}

