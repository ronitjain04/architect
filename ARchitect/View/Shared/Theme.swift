//
//  Theme.swift
//  ARchitect
//
//  Single source of truth for the app's visual language: colors, typography,
//  spacing, corner radii, and shared component styles. Every screen should
//  pull from here instead of hardcoding values so fonts, sizes, and colors
//  stay consistent.
//
//  Typography pairs Fraunces (a warm display serif, used for the ARchitect
//  wordmark and section headers) with Inter (a crisp UI sans used for body,
//  labels, and controls) — an editorial look on a light cream canvas.
//

import SwiftUI

// MARK: - Colors

extension Color {
    /// Near-white warm cream app background.
    static let appBackground = Color(hex: "#FCF9F4")
    /// Slightly deeper surface for cards / grouped content.
    static let appSurface = Color(hex: "#F6EEE2")
    /// Tan used for chips, pills, and secondary surfaces.
    static let appSurfaceAlt = Color(hex: "#EFE5D6")

    /// Primary brand brown (bars, primary buttons, key accents).
    static let appPrimary = Color(hex: "#635346")
    /// Warm gold accent (story rings, tags, highlights, CTAs).
    static let appAccent = Color(hex: "#C8852B")

    /// Primary text — deep warm brown for strong contrast on cream.
    static let appText = Color(hex: "#3E2E22")
    /// Secondary / muted text.
    static let appTextSecondary = Color(hex: "#8A7B6B")
    /// Text/icon color on top of primary or dark surfaces.
    static let appOnPrimary = Color(hex: "#FCF9F4")

    /// Hairline divider color.
    static let appDivider = Color(hex: "#ECE3D4")

    /// The "liked" heart color.
    static let appLike = Color(hex: "#E0533C")
}

// MARK: - Typography (Fraunces display + Inter body)

enum AppFont {
    /// Inter — the UI sans used for body text, labels, and controls.
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:   name = "Inter-Bold"
        case .semibold:               name = "Inter-SemiBold"
        case .medium:                 name = "Inter-Medium"
        default:                       name = "Inter-Regular"
        }
        return .custom(name, size: size)
    }

    /// Fraunces — the display serif used for the wordmark and section headers.
    static func fraunces(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:       name = "Fraunces-Bold"
        case .light, .thin, .ultraLight:  name = "Fraunces-Medium"
        case .regular, .medium:           name = "Fraunces-Medium"
        default:                           name = "Fraunces-SemiBold"
        }
        return .custom(name, size: size)
    }

    /// Back-compat alias — existing call sites that asked for the old rounded
    /// face now resolve to Inter at the requested size/weight.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        inter(size, weight)
    }

    // Display scale — Fraunces serif.
    static let largeTitle = fraunces(32, .semibold)
    static let title      = fraunces(26, .semibold)
    static let title2     = fraunces(21, .semibold)
    static let title3     = fraunces(18, .semibold)

    // Text scale — Inter sans.
    static let headline    = inter(15, .semibold)
    static let body        = inter(15, .regular)
    static let callout     = inter(14, .regular)
    static let subheadline  = inter(13, .regular)
    static let caption     = inter(12, .regular)
    static let button      = inter(15, .semibold)
}

// MARK: - Spacing

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Corner radius

enum AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 18
    static let pill: CGFloat = 999
}

// MARK: - Shared component styles

/// Soft elevated card surface used across grids and lists.
struct CardBackground: ViewModifier {
    var fill: Color = .appSurface
    var radius: CGFloat = AppRadius.md

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
    }
}

extension View {
    func cardBackground(fill: Color = .appSurface, radius: CGFloat = AppRadius.md) -> some View {
        modifier(CardBackground(fill: fill, radius: radius))
    }
}

/// Filled primary action button (brown bg, cream text).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.button)
            .foregroundColor(.appOnPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(Color.appPrimary)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Soft secondary action button (tan bg, brown text) — Instagram's quiet
/// "Edit profile" style.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.button)
            .foregroundColor(.appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(Color.appSurfaceAlt)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Shared Instagram-style components

/// Circular avatar showing an SF Symbol or a single-letter monogram.
struct Avatar: View {
    var systemImage: String? = nil
    var monogram: String? = nil
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle().fill(Color.appSurfaceAlt)
            if let systemImage {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
                    .foregroundColor(.appPrimary)
            } else if let monogram {
                Text(monogram.prefix(1).uppercased())
                    .font(AppFont.inter(size * 0.42, .semibold))
                    .foregroundColor(.appPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

