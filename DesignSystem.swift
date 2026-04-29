import SwiftUI

enum DS {
    enum Color {
        static let bg0 = SwiftUI.Color(red: 0.035, green: 0.038, blue: 0.048)
        static let bg1 = SwiftUI.Color(red: 0.055, green: 0.060, blue: 0.075)
        static let bg2 = SwiftUI.Color(red: 0.075, green: 0.082, blue: 0.102)
        static let bg3 = SwiftUI.Color(red: 0.100, green: 0.110, blue: 0.135)
        static let bg4 = SwiftUI.Color(red: 0.125, green: 0.138, blue: 0.170)
        static let fg1 = SwiftUI.Color(red: 0.930, green: 0.940, blue: 0.970)
        static let fg2 = SwiftUI.Color(red: 0.730, green: 0.760, blue: 0.820)
        static let fg3 = SwiftUI.Color(red: 0.520, green: 0.560, blue: 0.640)
        static let line1 = SwiftUI.Color.white.opacity(0.075)
        static let line2 = SwiftUI.Color.white.opacity(0.120)
        static let accent = SwiftUI.Color(red: 0.355, green: 0.540, blue: 1.000)
        static let accentSoft = SwiftUI.Color(red: 0.355, green: 0.540, blue: 1.000).opacity(0.145)
        static let success = SwiftUI.Color(red: 0.330, green: 0.860, blue: 0.560)
        static let warning = SwiftUI.Color(red: 0.950, green: 0.720, blue: 0.270)
        static let danger = SwiftUI.Color(red: 1.000, green: 0.360, blue: 0.330)
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 12
        static let panel: CGFloat = 22
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: 38, weight: .semibold, design: .default)
        static let h1 = SwiftUI.Font.system(size: 30, weight: .semibold, design: .default)
        static let h2 = SwiftUI.Font.system(size: 24, weight: .semibold, design: .default)
        static let h3 = SwiftUI.Font.system(size: 20, weight: .semibold, design: .default)
        static let h4 = SwiftUI.Font.system(size: 17, weight: .semibold, design: .default)
        static let body = SwiftUI.Font.system(size: 13.5, weight: .regular, design: .default)
        static let small = SwiftUI.Font.system(size: 12.5, weight: .regular, design: .default)
        static let eyebrow = SwiftUI.Font.system(size: 10.5, weight: .semibold, design: .default)
        static let mono = SwiftUI.Font.system(size: 12.5, weight: .regular, design: .monospaced)
    }
}

struct DSCard: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = DS.Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Color.bg2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DS.Color.line1, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 16)
    }
}

struct DSPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                    .fill(DS.Color.bg1.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                    .stroke(DS.Color.line1, lineWidth: 0.5)
            )
    }
}

extension View {
    func dsCard(padding: CGFloat = 20, cornerRadius: CGFloat = DS.Radius.card) -> some View {
        modifier(DSCard(padding: padding, cornerRadius: cornerRadius))
    }

    func dsPanel() -> some View {
        modifier(DSPanel())
    }
}

struct DSButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case ghost
        case danger
    }

    var variant: Variant = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.small.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(variant == .ghost ? 0 : 0.18))
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foregroundColor: SwiftUI.Color {
        switch variant {
        case .primary, .danger:
            return .white
        case .secondary, .ghost:
            return DS.Color.fg1
        }
    }

    private var borderColor: SwiftUI.Color {
        switch variant {
        case .primary:
            return DS.Color.accent.opacity(0.55)
        case .danger:
            return DS.Color.danger.opacity(0.45)
        case .secondary:
            return DS.Color.line2
        case .ghost:
            return .clear
        }
    }

    private func background(isPressed: Bool) -> SwiftUI.Color {
        let pressedBoost = isPressed ? 0.10 : 0
        switch variant {
        case .primary:
            return DS.Color.accent.opacity(0.92 - pressedBoost)
        case .danger:
            return DS.Color.danger.opacity(0.82 - pressedBoost)
        case .secondary:
            return DS.Color.bg4.opacity(0.95 - pressedBoost)
        case .ghost:
            return DS.Color.bg4.opacity(isPressed ? 0.32 : 0.0)
        }
    }
}

struct DSBadge: View {
    enum Variant {
        case neutral
        case accent
        case success
        case warning
        case danger
    }

    let title: String
    var variant: Variant = .neutral

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(title)
                .font(DS.Font.eyebrow)
                .textCase(.uppercase)
                .tracking(0.7)
        }
        .foregroundStyle(tint == DS.Color.fg3 ? DS.Color.fg2 : tint)
        .padding(.horizontal, 10)
        .frame(height: 25)
        .background(tint.opacity(0.13), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 0.5))
    }

    private var tint: SwiftUI.Color {
        switch variant {
        case .neutral:
            return DS.Color.fg3
        case .accent:
            return DS.Color.accent
        case .success:
            return DS.Color.success
        case .warning:
            return DS.Color.warning
        case .danger:
            return DS.Color.danger
        }
    }
}
