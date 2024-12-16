import SwiftUI

struct AppTheme {
    static let colors = ThemeColors()
    
    struct ThemeColors {
        // Base colors
        let primary = Color("PrimaryColor") // Soft pine: rgb(89, 126, 108)
        let secondary = Color("SecondaryColor") // Warm taupe: rgb(133, 117, 109)
        
        // Accent colors (natural tones)
        let sage = Color("SageColor") // Forest sage: rgb(115, 143, 116)
        let moss = Color("MossColor") // Deep moss: rgb(134, 151, 121)
        let pine = Color("PineColor") // Dark pine: rgb(74, 102, 86)
        
        let clay = Color("ClayColor") // Warm earth: rgb(164, 131, 116)
        let bark = Color("BarkColor") // Rich bark: rgb(120, 98, 86)
        let sand = Color("SandColor") // Light sand: rgb(211, 198, 184)
        
        let sky = Color("SkyColor") // Soft sky: rgb(173, 198, 208)
        let ocean = Color("OceanColor") // Deep ocean: rgb(147, 178, 191)
        let mist = Color("MistColor") // Morning mist: rgb(200, 212, 216)
        
        // Functional colors
        let success = Color("SuccessColor") // Forest green: rgb(89, 126, 108)
        let warning = Color("WarningColor") // Warm ochre: rgb(191, 162, 119)
        let error = Color("ErrorColor") // Muted rust: rgb(171, 106, 104)
        
        // Background colors
        let background = Color("BackgroundColor") // Cream: rgb(249, 246, 241)
        let secondaryBackground = Color("SecondaryBackgroundColor") // Soft beige: rgb(243, 239, 234)
        
        // Text colors
        let textPrimary = Color("TextPrimaryColor") // Deep brown: rgb(59, 48, 43)
        let textSecondary = Color("TextSecondaryColor") // Warm gray: rgb(108, 98, 95)
    }
} 