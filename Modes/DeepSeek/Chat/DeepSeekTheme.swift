import SwiftUI
import UIKit

/// DeepSeek's real design tokens, resolved to concrete light/dark hex from their
/// compiled design-system stylesheet (`--dsw-alias-*`). These are the actual app
/// colors — match, don't approximate.
///
/// Identity-defining choices: brand blue is `#4D6BFE` (accent `#3964FE` light /
/// `#5686FE` dark); **only the user message gets a bubble** (`#EDF3FE` / `#2C2C2E`)
/// — the assistant reply renders directly on the background. Font is system SF Pro
/// (the native app ships no custom UI font).
enum DS {

    // MARK: Color

    private static func hex(_ v: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: 1.0
        )
    }

    /// A dynamic color that resolves per light/dark trait.
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? hex(dark) : hex(light) })
    }

    enum Palette {
        // Surfaces
        static let bg = dyn(0xFFFFFF, 0x151517)          // app background
        static let layer1 = dyn(0xFFFFFF, 0x232324)
        static let layer2 = dyn(0xF9FAFB, 0x2C2C2E)      // cards / raised
        static let layer3 = dyn(0xEBEEF2, 0x353638)
        static let separator = dyn(0xEBEEF2, 0x353638)

        // Text
        static let textPrimary = dyn(0x0F1115, 0xF9FAFB)
        static let textSecondary = dyn(0x61666B, 0xCFD3D6)
        static let textTertiary = dyn(0x81858C, 0xADB2B8)
        static let textCaption = dyn(0xADB2B8, 0x81858C)

        // Brand
        static let brand = dyn(0x3964FE, 0x5686FE)       // UI accent
        static let brandText = dyn(0x3964FE, 0x679EFE)   // links
        static let brandHeadline = dyn(0x4D6BFE, 0x4D6BFE)

        // Chat
        static let userBubble = dyn(0xEDF3FE, 0x2C2C2E)
        static let userBubbleHighlight = dyn(0xD3E2FE, 0x43454A)
        static let userBubbleText = dyn(0x0F1115, 0xF9FAFB)

        // Input
        static let inputFill = dyn(0xF9FAFB, 0x2C2C2E)
        static let inputBorder = dyn(0xEBEEF2, 0x353638)
        static let inputPlaceholder = dyn(0x81858C, 0xADB2B8)

        // Ghost pill toggle (DeepThink / Search) — active state
        static let toggleActiveFill = dyn(0xEDF3FE, 0x283142)
        static let toggleActiveBorder = dyn(0xB7C8FE, 0x4868B2)
        static let toggleIdleBorder = dyn(0xE1E5EE, 0x43454A)

        // Code
        static let codeBlockBg = dyn(0xF9FAFB, 0x1B1B1C)
        static let inlineCodeBg = dyn(0xEBEEF2, 0x2C2C2E)

        // State
        static let error = dyn(0xEC1313, 0xF25A5A)
        static let success = dyn(0x22C55E, 0x22C55E)
    }

    // MARK: Type (system SF Pro, DeepSeek's size/weight scale)

    enum Font {
        static let welcomeTitle = SwiftUI.Font.system(size: 26, weight: .semibold)
        static let title = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 16)          // message text (17≈iOS default; DeepSeek≈16)
        static let secondary = SwiftUI.Font.system(size: 13)
        static let caption = SwiftUI.Font.system(size: 12)
        static let pill = SwiftUI.Font.system(size: 13, weight: .medium)
        static let code = SwiftUI.Font.system(size: 14, design: .monospaced)
    }

    // MARK: Metrics

    enum Metric {
        static let bubbleRadius: CGFloat = 20
        static let bubbleMaxWidthFraction: CGFloat = 0.82
        static let messageBodyLineSpacing: CGFloat = 5   // 14px→25 line-height feel
        static let inputRadius: CGFloat = 22
        static let pillRadius: CGFloat = 16
        static let hPad: CGFloat = 16
        // iPad: the real app is the phone layout scaled up (single column, no split
        // view). Cap + center the column so it doesn't stretch edge-to-edge on a large
        // iPad; no effect on iPhone (screen width is already below these).
        static let maxContentWidth: CGFloat = 900
        static let maxAuthWidth: CGFloat = 420
        static let maxDrawerWidth: CGFloat = 340
    }
}
