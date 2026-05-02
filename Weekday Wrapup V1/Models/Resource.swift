import Foundation

/// FILE: Models/Resource.swift
/// Canonical keyword-matched support resource.
struct Resource: Equatable, Hashable {
    let title: String
    let url: String
    let tags: [String]
}
