//
//  Weekday_Wrapup_V1Tests.swift
//  Weekday Wrapup V1Tests
//
//  Created by Shannon  Dupont on 12/14/24.
//

import Testing
@testable import Weekday_Wrapup_V1

struct Weekday_Wrapup_V1Tests {

    @Test func recommendationEngineColdStartReturnsCappedResults() async throws {
        let engine = PersonalizedRecommendationEngine()
        let recs = engine.generate(
            emotion: "sad",
            intensity: 8,
            tags: [],
            preferences: nil,
            history: [],
            weather: .neutral
        )
        #expect(!recs.isEmpty)
        #expect(recs.count >= 1 && recs.count <= 5)
    }

    @Test func therapyEngineNormalizesMappedKeywords() async throws {
        let recs = TherapyResourceEngine.matchResources(
            text: "I've been spiraling and feeling drained.",
            emotions: []
        )
        #expect(!recs.isEmpty)
        #expect(recs.contains(where: { $0.url.contains("anxiety") || $0.url.contains("burnout") }))
    }

    @Test func therapyEngineReturnsNothingWithoutKeywordMatch() async throws {
        let recs = TherapyResourceEngine.matchResources(
            text: "I ate pasta and watched a movie.",
            emotions: []
        )
        #expect(recs.isEmpty)
    }

}
