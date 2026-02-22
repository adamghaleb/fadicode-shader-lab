import SwiftUI
import AppKit

/// Copy of fadicode's TaskFlashOverlay for testing alongside the working state shader.
struct TaskFlashOverlay: View {
    let tier: String?
    var themeColor: NSColor? = nil

    @State private var flashOpacity: Double = 0
    @State private var borderOpacity: Double = 0
    @State private var fillColor: Color = .clear
    @State private var borderWidth: CGFloat = 0
    @State private var glowRadius1: CGFloat = 0
    @State private var glowRadius2: CGFloat = 0

    private var celebrationColor: Color {
        if let tc = themeColor { return Color(nsColor: tc) }
        return Color(red: 0.1, green: 0.9, blue: 0.3)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)
                .opacity(flashOpacity)

            Rectangle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            fillColor,
                            fillColor.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 500
                    )
                )
                .opacity(borderOpacity * 0.8)

            Rectangle()
                .strokeBorder(fillColor, lineWidth: borderWidth)
                .shadow(color: fillColor, radius: glowRadius1)
                .shadow(color: fillColor.opacity(0.4), radius: glowRadius2)
                .opacity(borderOpacity)
        }
        .allowsHitTesting(false)
        .onChange(of: tier) { newTier in
            if let t = newTier {
                let isShort = t == "short"
                let isLong = t == "long"
                fillColor = isShort ? .white : celebrationColor
                borderWidth = isLong ? 6 : 4
                glowRadius1 = isLong ? 40 : 20
                glowRadius2 = isLong ? 70 : 40

                let mo: Double = isShort ? 0.12 : (isLong ? 0.7 : 0.45)
                let bo: Double = isShort ? 0.0 : (isLong ? 1.0 : 0.7)
                let hold: Double = isShort ? 0.0 : (isLong ? 0.8 : 0.2)
                let fade: Double = isShort ? 0.25 : (isLong ? 3.0 : 0.8)

                withAnimation(.easeIn(duration: 0.08)) {
                    flashOpacity = mo
                    borderOpacity = bo
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                    withAnimation(.easeOut(duration: fade)) {
                        flashOpacity = 0
                        borderOpacity = 0
                    }
                }
            } else {
                flashOpacity = 0
                borderOpacity = 0
            }
        }
    }
}
