import Foundation
import FirebaseFirestore

/// FILE: Models/Comment.swift
/// Maps `posts/{postId}/comments/{commentId}` documents (top-level + replies via `parentCommentId`).

struct Comment: Identifiable, Equatable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let text: String
    let createdAt: Date?
    /// When set, this row is a reply nested under the parent comment in UI.
    let parentCommentId: String?
    var likes: Int
    var likedBy: Set<String>
    /// Quick emoji tallies (e.g. "❤️": 3); keys are literal emoji strings.
    var reactions: [String: Int]
    /// Nested replies (built from flat Firestore rows via `Comment.nestedTree`).
    var replies: [Comment] = []

    init(
        id: String,
        userId: String,
        userName: String,
        text: String,
        createdAt: Date? = nil,
        parentCommentId: String? = nil,
        likes: Int = 0,
        likedBy: Set<String> = [],
        reactions: [String: Int] = [:],
        replies: [Comment] = []
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.text = text
        self.createdAt = createdAt
        self.parentCommentId = parentCommentId
        self.likes = likes
        self.likedBy = likedBy
        self.reactions = reactions
        self.replies = replies
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let text = data["text"] as? String else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let parentCommentId = data["parentCommentId"] as? String
        let likes = Comment.intFromFirestore(data["likeCount"])
        let likedArray = data["likedBy"] as? [String] ?? []
        let reactionsMap = Self.reactionsFromFirestore(data["reactions"] as? [String: Any])
        self.id = document.documentID
        self.userId = userId
        self.userName = userName
        self.text = text
        self.createdAt = createdAt
        self.parentCommentId = parentCommentId
        self.likes = likes
        self.likedBy = Set(likedArray)
        self.reactions = reactionsMap
        self.replies = []
    }

    static func == (lhs: Comment, rhs: Comment) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Builds a tree from a flat Firestore-ordered list (same `createdAt` ordering preserved among siblings).
    static func nestedTree(from flat: [Comment]) -> [Comment] {
        let sorted = flat.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        let repliesOnly = sorted.filter { $0.parentCommentId != nil }
        let childrenByParent = Dictionary(grouping: repliesOnly, by: { $0.parentCommentId! })

        func attachReplies(for parentId: String) -> [Comment] {
            guard let raw = childrenByParent[parentId] else { return [] }
            let list = raw.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            return list.map { node in
                var copy = node
                copy.replies = attachReplies(for: node.id)
                return copy
            }
        }

        let roots = sorted.filter { $0.parentCommentId == nil }
        return roots.map { root in
            var r = root
            r.replies = attachReplies(for: root.id)
            return r
        }
    }

    private static func intFromFirestore(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return 0
    }

    private static func reactionsFromFirestore(_ raw: [String: Any]?) -> [String: Int] {
        guard let raw else { return [:] }
        var out: [String: Int] = [:]
        for (k, v) in raw {
            out[k] = intFromFirestore(v)
        }
        return out
    }

    /// For Firestore transactions when merging reaction maps.
    static func parseReactionsDict(_ raw: [String: Any]?) -> [String: Int] {
        reactionsFromFirestore(raw)
    }
}
