import Foundation

struct DopamineMenu: Codable, Equatable {
    var appetizers: [String] = []
    var mains: [String] = []
    var sides: [String] = []
    var desserts: [String] = []
    var specials: [String] = []

    var barriers: [String] = []
    var prepNotes: [String] = []

    var isEmpty: Bool {
        appetizers.isEmpty && mains.isEmpty && sides.isEmpty && desserts.isEmpty && specials.isEmpty
            && barriers.isEmpty && prepNotes.isEmpty
    }

    func sanitized() -> DopamineMenu {
        var copy = self
        copy.appetizers = clean(copy.appetizers, max: 6)
        copy.mains = clean(copy.mains, max: 6)
        copy.sides = clean(copy.sides, max: 6)
        copy.desserts = clean(copy.desserts, max: 6)
        copy.specials = clean(copy.specials, max: 6)
        copy.barriers = clean(copy.barriers, max: 8)
        copy.prepNotes = clean(copy.prepNotes, max: 8)
        return copy
    }

    private func clean(_ items: [String], max: Int) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(trimmed)
            if out.count >= max { break }
        }
        return out
    }

    static func fromFirestoreDictionary(_ dict: [String: Any]) throws -> DopamineMenu {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return try JSONDecoder().decode(DopamineMenu.self, from: data)
    }

    func asFirestoreDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self.sanitized())
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }
}
