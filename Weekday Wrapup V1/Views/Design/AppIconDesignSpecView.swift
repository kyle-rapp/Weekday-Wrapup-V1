import SwiftUI

/// FILE: Views/Design/AppIconDesignSpecView.swift
/// Abstract color-wheel icon reference for design/dev handoff.
struct AppIconDesignSpecView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.90, blue: 0.86),
                            Color(red: 0.92, green: 0.95, blue: 1.0),
                            Color(red: 0.88, green: 0.96, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [.pink, .orange, .yellow, .green, .mint, .blue, .purple, .pink],
                        center: .center
                    ),
                    lineWidth: 20
                )
                .padding(34)
            Circle()
                .fill(.white.opacity(0.92))
                .padding(72)
            Image(systemName: "sparkles")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.indigo.opacity(0.75))
        }
        .frame(width: 240, height: 240)
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

#if DEBUG
#Preview("Icon Spec") {
    AppIconDesignSpecView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
#endif
