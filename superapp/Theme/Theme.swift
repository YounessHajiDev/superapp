//
//  Theme.swift
//  InkMatching
//
//  Created by You on 2025-09-08.
//

import SwiftUI

// MARK: - Theme namespace

enum Theme {

    // MARK: Colors
    enum Colors {
        // System-aware semantic colors
        static var background: Color { Color(.systemBackground) }
        static var surface: Color { Color(.secondarySystemBackground) }
        static var surface2: Color { Color(.tertiarySystemBackground) }
        static var stroke: Color { Color(.separator) }
        static var text: Color { Color.primary }
        static var textSecondary: Color { Color.secondary }
        static var accent: Color { Color.accentColor }
        static var danger: Color { Color.red }
        static var success: Color { Color.green }
        static var warning: Color { Color.orange }
    }

    // MARK: Fonts
    enum Fonts {
        static var largeTitle: Font { .system(.largeTitle, design: .rounded).weight(.bold) }
        static var title: Font { .system(.title, design: .rounded).weight(.semibold) }
        static var title2: Font { .system(.title2, design: .rounded).weight(.semibold) }
        static var title3: Font { .system(.title3, design: .rounded).weight(.semibold) }
        static var headline: Font { .system(.headline, design: .rounded) }
        static var callout: Font { .system(.callout, design: .rounded) }
        static var body: Font { .system(.body, design: .rounded) }
        static var subheadline: Font { .system(.subheadline, design: .rounded) }
        static var caption: Font { .system(.caption, design: .rounded) }
        static var footnote: Font { .system(.footnote, design: .rounded) }
    }

    // MARK: Layout
    enum Layout {
        static let cornerRadius: CGFloat = 16
        static let cornerRadiusXL: CGFloat = 20
        static let strokeWidth: CGFloat = 0.5
        static let cardPadding: CGFloat = 14
        static let chipPaddingV: CGFloat = 6
        static let chipPaddingH: CGFloat = 10
        static let avatar: CGFloat = 44
        static let shadowRadius: CGFloat = 14
    }
}

// MARK: - Components

// Card container with soft glass look
struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = Theme.Layout.cardPadding
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadiusXL, style: .continuous)
                .fill(Theme.Colors.surface)
                .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.06), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadiusXL, style: .continuous)
                .stroke(Theme.Colors.stroke.opacity(0.7), lineWidth: Theme.Layout.strokeWidth)
        )
    }
}

// Section header with optional subtitle
struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).imageScale(.medium).foregroundStyle(Theme.Colors.textSecondary)
                }
                Text(title).font(Theme.Fonts.title3)
            }
            if let subtitle {
                Text(subtitle).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}

// Small pill tag (used in API demo)
struct TagView: View {
    var text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.small)
            }
            Text(text).font(Theme.Fonts.caption)
        }
        .padding(.vertical, Theme.Layout.chipPaddingV)
        .padding(.horizontal, Theme.Layout.chipPaddingH)
        .background(Theme.Colors.accent.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(Theme.Colors.accent.opacity(0.2), lineWidth: Theme.Layout.strokeWidth))
        .foregroundStyle(Theme.Colors.accent)
    }
}

// Avatar with optional remote URL and initials fallback
struct AvatarView: View {
    var initials: String
    var urlString: String? = nil
    var size: CGFloat = Theme.Layout.avatar

    var body: some View {
        ZStack {
            Circle().fill(Theme.Colors.surface2)
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().scaleEffect(0.8)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Text(initials).font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Text(initials).font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.Colors.stroke, lineWidth: Theme.Layout.strokeWidth))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.callout.weight(.semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .fill(Theme.Colors.accent)
            )
            .foregroundStyle(.white)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: Theme.Layout.strokeWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 10, y: 4)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.callout.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.stroke, lineWidth: Theme.Layout.strokeWidth)
            )
            .foregroundStyle(Theme.Colors.text)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct TertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.callout)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface2.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.stroke.opacity(0.7), lineWidth: Theme.Layout.strokeWidth)
            )
            .foregroundStyle(Theme.Colors.text)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - TextField style

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(Theme.Fonts.body)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.stroke, lineWidth: Theme.Layout.strokeWidth)
            )
    }
}

// MARK: - View helpers / modifiers

enum ElevationLevel { case level0, level1, level2 }

extension View {
    /// Subtle elevation shadow
    func elevated(_ level: ElevationLevel) -> some View {
        modifier(ElevationModifier(level: level))
    }

    /// Frosted glass background (for search bars / floating panels)
    func glassBackground(cornerRadius: CGFloat = Theme.Layout.cornerRadiusXL) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Theme.Colors.stroke.opacity(0.8), lineWidth: Theme.Layout.strokeWidth)
                )
        )
    }

    /// Modern list style (no grouped background, clean separators)
    func modernList() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
    }
}

private struct ElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let level: ElevationLevel

    func body(content: Content) -> some View {
        content.shadow(color: shadowColor, radius: radius, y: y)
    }

    private var shadowColor: Color {
        let base: Double = (scheme == .dark) ? 0.5 : 0.12
        switch level {
        case .level0: return .black.opacity(0)
        case .level1: return .black.opacity(base)
        case .level2: return .black.opacity(base + 0.1)
        }
    }

    private var radius: CGFloat {
        switch level {
        case .level0: return 0
        case .level1: return 10
        case .level2: return 16
        }
    }

    private var y: CGFloat {
        switch level {
        case .level0: return 0
        case .level1: return 4
        case .level2: return 8
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ThemePreview_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionHeader(title: "Profile", subtitle: "Subheadline", systemImage: "person.fill")

                HStack {
                    AvatarView(initials: "AA", urlString: nil)
                    AvatarView(initials: "BC", urlString: "https://picsum.photos/100")
                    Spacer()
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Card Title").font(Theme.Fonts.title3)
                        Text("Body text lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        HStack {
                            Button("Primary") {}.buttonStyle(PrimaryButtonStyle())
                            Button("Secondary") {}.buttonStyle(SecondaryButtonStyle())
                        }
                        Button("Tertiary") {}.buttonStyle(TertiaryButtonStyle())
                        HStack {
                            TagView(text: "UV 3", systemImage: "sun.max.fill")
                            TagView(text: "Clear", systemImage: "cloud")
                        }
                        TextField("Display name", text: .constant(""))
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 20)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .preferredColorScheme(.light)

        ScrollView {
            VStack(spacing: 16) {
                SectionHeader(title: "Profile", subtitle: "Subheadline", systemImage: "person.fill")
                Card { Text("Dark mode card").font(Theme.Fonts.body) }
                    .padding(.horizontal)
            }
            .padding(.top, 20)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
#endif
