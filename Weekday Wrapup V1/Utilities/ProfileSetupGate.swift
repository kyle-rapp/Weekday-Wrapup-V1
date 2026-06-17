import Foundation

struct ProfileSetupGateResult {
    let needsBasicSetup: Bool
    let hasDisplayName: Bool
    let hasZodiacSign: Bool
    let hasDurableProfileImage: Bool
    let reason: String
}

enum ProfileSetupGate {
    static func evaluate(profile: UserProfile?, appUser: AppUser?) -> ProfileSetupGateResult {
        let displayName = firstNonEmpty(profile?.name, appUser?.name)
        let zodiacSign = firstNonEmpty(profile?.zodiacSign, appUser?.zodiacSign)
        let profileImageURL = firstNonEmpty(profile?.profileImageURL, appUser?.profileImageURL)

        let hasDisplayName = displayName != nil
        let hasZodiacSign = zodiacSign != nil
        let hasDurableProfileImage = profileImageURL != nil
        let needsBasicSetup = !hasDisplayName || !hasZodiacSign

        let reason: String
        if needsBasicSetup {
            reason = !hasDisplayName ? "missing_display_name" : "missing_zodiac"
        } else if !hasDurableProfileImage {
            reason = "missing_profile_image_optional_edit"
        } else {
            reason = "complete"
        }

        return ProfileSetupGateResult(
            needsBasicSetup: needsBasicSetup,
            hasDisplayName: hasDisplayName,
            hasZodiacSign: hasZodiacSign,
            hasDurableProfileImage: hasDurableProfileImage,
            reason: reason
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
