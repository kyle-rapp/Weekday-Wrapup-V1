import SwiftUI

struct AppTheme {
    static let colors = ThemeColors()
    
    struct ThemeColors {
        // Base colors
        let primary = Color(red: 89 / 255, green: 126 / 255, blue: 108 / 255) // Soft pine
        let secondary = Color(red: 133 / 255, green: 117 / 255, blue: 109 / 255) // Warm taupe
        
        // Accent colors (natural tones)
        let sage = Color(red: 115 / 255, green: 143 / 255, blue: 116 / 255) // Forest sage
        let moss = Color(red: 134 / 255, green: 151 / 255, blue: 121 / 255) // Deep moss
        let pine = Color(red: 74 / 255, green: 102 / 255, blue: 86 / 255) // Dark pine
        
        let clay = Color(red: 164 / 255, green: 131 / 255, blue: 116 / 255) // Warm earth
        let bark = Color(red: 120 / 255, green: 98 / 255, blue: 86 / 255) // Rich bark
        let sand = Color(red: 211 / 255, green: 198 / 255, blue: 184 / 255) // Light sand
        
        let sky = Color(red: 173 / 255, green: 198 / 255, blue: 208 / 255) // Soft sky
        let ocean = Color(red: 147 / 255, green: 178 / 255, blue: 191 / 255) // Deep ocean
        let mist = Color(red: 200 / 255, green: 212 / 255, blue: 216 / 255) // Morning mist
        
        // Functional colors
        let success = Color(red: 89 / 255, green: 126 / 255, blue: 108 / 255) // Forest green
        let warning = Color(red: 191 / 255, green: 162 / 255, blue: 119 / 255) // Warm ochre
        let error = Color(red: 171 / 255, green: 106 / 255, blue: 104 / 255) // Muted rust
        
        // Background colors — semantic so Light/Dark always contrast with text
        let background = Color(.systemBackground)
        let secondaryBackground = Color(.systemGroupedBackground)

        // Text colors — semantic; avoids asset/catalog mismatches that hid Learn tab copy
        let textPrimary = Color.primary
        let textSecondary = Color.secondary
    }
} 