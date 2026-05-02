import Foundation

/// FILE: Models/FeedScoreContext.swift
/// Context for intelligent ranked feed ordering.
struct FeedScoreContext {
    let currentUserId: String
    let followingIds: Set<String>
    let now: Date
}
