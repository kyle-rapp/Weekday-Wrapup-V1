import Foundation

actor EmotionalEventDeduper {
    private var recent: [String: Date] = [:]
    private let dedupeWindow: TimeInterval = 2.5

    func shouldLog(signature: String, now: Date = Date()) -> Bool {
        prune(now: now)
        if let seenAt = recent[signature], now.timeIntervalSince(seenAt) < dedupeWindow {
            return false
        }
        recent[signature] = now
        return true
    }

    private func prune(now: Date) {
        recent = recent.filter { now.timeIntervalSince($0.value) < dedupeWindow }
    }
}

final class EmotionalEventStreamService {
    private let firestore: FirestoreManager
    private let adaptiveEngine: AdaptiveLearningEngine
    private static let deduper = EmotionalEventDeduper()

    init(firestore: FirestoreManager) {
        self.firestore = firestore
        self.adaptiveEngine = AdaptiveLearningEngine(firestore: firestore)
    }

    func logEvent(_ event: EmotionalEvent) async {
        let signature = [
            event.userId,
            event.eventType.rawValue,
            event.actionType.rawValue,
            event.itemId ?? "_",
            event.source.rawValue,
            String(event.didHelp ?? false)
        ].joined(separator: "|")
        let shouldLog = await Self.deduper.shouldLog(signature: signature, now: event.timestamp)
        guard shouldLog else {
            AppLogger.log("[EVENT_STREAM] deduped signature=\(signature)")
            return
        }
        do {
            try await firestore.saveEmotionalEvent(userId: event.userId, event: event)
            await adaptiveEngine.processEvent(event)
        } catch {
            AppLogger.error("Event stream write failed: \(error.localizedDescription)")
        }
    }

    func logRecommendationInteraction(
        userId: String,
        recommendation: Recommendation,
        actionType: ActionType,
        source: EventSource,
        didHelp: Bool? = nil,
        emotionBefore: EmotionSnapshot? = nil,
        emotionAfter: EmotionSnapshot? = nil,
        metadata: [String: String] = [:]
    ) async {
        let stable = StableItem.fromRecommendation(recommendation)
        let intensityChange = intensityDelta(before: emotionBefore, after: emotionAfter)
        let event = EmotionalEvent(
            eventId: makeEventId(
                userId: userId,
                eventType: .recommendationInteraction,
                actionType: actionType,
                itemId: stable.itemId,
                source: source
            ),
            userId: userId,
            timestamp: Date(),
            eventType: .recommendationInteraction,
            emotionBefore: emotionBefore,
            emotionAfter: emotionAfter,
            actionType: actionType,
            itemId: stable.itemId,
            itemTitle: stable.title,
            source: source,
            didHelp: didHelp,
            intensityChange: intensityChange,
            tags: recommendation.tags,
            metadata: metadata.merging(["category": stable.category]) { current, _ in current }
        )
        await logEvent(event)

        // Preserve existing recommendation behavior collection writes.
        do {
            if let didHelp {
                try await firestore.submitRecommendationFeedback(
                    userId: userId,
                    recommendationId: recommendation.id.uuidString,
                    title: recommendation.title,
                    reason: recommendation.reason,
                    type: recommendation.type,
                    helpful: didHelp
                )
                if didHelp {
                    try await firestore.recordRecommendationAccepted(userId: userId, recommendationId: recommendation.id.uuidString)
                } else {
                    try await firestore.recordRecommendationDismissed(userId: userId, recommendationId: recommendation.id.uuidString)
                }
            }
        } catch {
            AppLogger.error("Recommendation compatibility writes failed: \(error.localizedDescription)")
        }
    }

    func logRecommendationShown(
        userId: String,
        recommendation: Recommendation,
        source: EventSource,
        emotionBefore: EmotionSnapshot? = nil
    ) async {
        let stable = StableItem.fromRecommendation(recommendation)
        let event = EmotionalEvent(
            eventId: makeEventId(
                userId: userId,
                eventType: .recommendationInteraction,
                actionType: .reflect,
                itemId: stable.itemId,
                source: source
            ),
            userId: userId,
            timestamp: Date(),
            eventType: .recommendationInteraction,
            emotionBefore: emotionBefore,
            emotionAfter: nil,
            actionType: .reflect,
            itemId: stable.itemId,
            itemTitle: stable.title,
            source: source,
            didHelp: nil,
            intensityChange: nil,
            tags: recommendation.tags,
            metadata: ["interaction": "shown", "category": stable.category]
        )
        await logEvent(event)
        do {
            try await firestore.recordRecommendationShown(userId: userId, recommendationId: recommendation.id.uuidString)
        } catch {
            AppLogger.error("Recommendation shown compatibility write failed: \(error.localizedDescription)")
        }
    }

    func logDopamineMenuAction(
        userId: String,
        eventType: EmotionalEventType,
        actionType: ActionType,
        item: StableItem,
        source: EventSource,
        emotionBefore: EmotionSnapshot? = nil,
        emotionAfter: EmotionSnapshot? = nil,
        didHelp: Bool? = nil,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) async {
        let event = EmotionalEvent(
            eventId: makeEventId(
                userId: userId,
                eventType: eventType,
                actionType: actionType,
                itemId: item.itemId,
                source: source
            ),
            userId: userId,
            timestamp: Date(),
            eventType: eventType,
            emotionBefore: emotionBefore,
            emotionAfter: emotionAfter,
            actionType: actionType,
            itemId: item.itemId,
            itemTitle: item.title,
            source: source,
            didHelp: didHelp,
            intensityChange: intensityDelta(before: emotionBefore, after: emotionAfter),
            tags: tags,
            metadata: metadata.merging(["category": item.category]) { current, _ in current }
        )
        await logEvent(event)
    }

    func logEmotionCheckIn(
        userId: String,
        source: EventSource,
        emotionBefore: EmotionSnapshot?,
        emotionAfter: EmotionSnapshot,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) async {
        let event = EmotionalEvent(
            eventId: makeEventId(
                userId: userId,
                eventType: .emotionCheckIn,
                actionType: .save,
                itemId: nil,
                source: source
            ),
            userId: userId,
            timestamp: Date(),
            eventType: .emotionCheckIn,
            emotionBefore: emotionBefore,
            emotionAfter: emotionAfter,
            actionType: .save,
            itemId: nil,
            itemTitle: nil,
            source: source,
            didHelp: nil,
            intensityChange: intensityDelta(before: emotionBefore, after: emotionAfter),
            tags: tags,
            metadata: metadata
        )
        await logEvent(event)
    }

    func logHabitSignal(
        userId: String,
        signal: HabitSignal,
        source: EventSource,
        metadata: [String: String] = [:]
    ) async {
        do {
            try await firestore.saveHabitSignal(signal, userId: userId)
        } catch {
            AppLogger.error("Habit signal compatibility write failed: \(error.localizedDescription)")
        }
        let before = EmotionSnapshot(emotion: signal.emotionBefore, intensity: Double(signal.intensityBefore))
        let after = signal.emotionAfter.map { EmotionSnapshot(emotion: $0, intensity: Double(signal.intensityAfter ?? signal.intensityBefore)) }
        let event = EmotionalEvent(
            eventId: makeEventId(
                userId: userId,
                eventType: .habitSignal,
                actionType: .reflect,
                itemId: StableId.make(prefix: "habit", title: signal.actionType, category: "habit"),
                source: source
            ),
            userId: userId,
            timestamp: signal.createdAt,
            eventType: .habitSignal,
            emotionBefore: before,
            emotionAfter: after,
            actionType: .reflect,
            itemId: StableId.make(prefix: "habit", title: signal.actionType, category: "habit"),
            itemTitle: signal.actionType,
            source: source,
            didHelp: nil,
            intensityChange: intensityDelta(before: before, after: after),
            tags: [signal.actionType],
            metadata: metadata
        )
        await logEvent(event)
    }

    private func makeEventId(
        userId: String,
        eventType: EmotionalEventType,
        actionType: ActionType,
        itemId: String?,
        source: EventSource
    ) -> String {
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let seed = "\(userId)|\(eventType.rawValue)|\(actionType.rawValue)|\(itemId ?? "_")|\(source.rawValue)|\(millis)"
        let hash = StableId.make(prefix: "evt", title: seed, category: "event")
        return "event_\(millis)_\(hash.replacingOccurrences(of: "evt_", with: ""))"
    }

    private func intensityDelta(before: EmotionSnapshot?, after: EmotionSnapshot?) -> Double? {
        guard let before, let after else { return nil }
        return after.intensity - before.intensity
    }
}
