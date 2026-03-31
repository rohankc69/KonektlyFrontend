//
//  Theme.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct Theme {
    
    // MARK: - Colors (Uber-inspired palette with Dark Mode support)
    struct Colors {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let accent = Color(red: 0.22, green: 0.35, blue: 0.96) // Professional blue
        
        // Background colors
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
        
        // Text colors
        static let primaryText = Color(UIColor.label)
        static let secondaryText = Color(UIColor.secondaryLabel)
        static let tertiaryText = Color(UIColor.tertiaryLabel)
        
        // Functional colors
        static let success = Color(red: 0.18, green: 0.62, blue: 0.52) // Muted teal
        static let warning = Color.orange
        static let error = Color(red: 0.86, green: 0.24, blue: 0.24) // Muted red
        static let urgent = Color(red: 0.86, green: 0.24, blue: 0.24)
        
        // Card and surface colors
        static let cardBackground = Color(UIColor.secondarySystemBackground)
        static let overlayBackground = Color(UIColor.systemBackground).opacity(0.95)
        
        // Border and separator
        static let border = Color(UIColor.separator)
        static let divider = Color(UIColor.separator)
        
        // Input field background — adaptive for dark mode
        static let inputBackground = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? .tertiarySystemBackground
                : UIColor(red: 0.93, green: 0.94, blue: 0.97, alpha: 1)
        })
        static let inputBorderFocused = Color(red: 0.22, green: 0.35, blue: 0.96)

        // Solid button background — always supports white text
        static let buttonPrimary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.22, green: 0.35, blue: 0.96, alpha: 1) // accent blue
                : UIColor.label // black
        })
        
        // Map overlay colors
        static let mapOverlayBackground = Color(UIColor.systemBackground).opacity(0.95)
        static let chipBackground = Color(UIColor.tertiarySystemBackground)
    }
    
    // MARK: - Typography (SF Font)
    struct Typography {
        // Large titles
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        
        // Headlines
        static let headline = Font.headline
        static let headlineSemibold = Font.headline.weight(.semibold)
        static let headlineBold = Font.headline.weight(.bold)
        
        // Body text
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let bodySemibold = Font.body.weight(.semibold)
        
        // Captions and footnotes
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.1), 4, 0, 2
        )
        
        static let medium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.15), 8, 0, 4
        )
        
        static let large: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.2), 16, 0, 8
        )
    }
    
    // MARK: - Sizes
    struct Sizes {
        // Button heights
        static let buttonHeight: CGFloat = 58
        static let smallButtonHeight: CGFloat = 46
        
        // Avatar sizes
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 48
        static let avatarLarge: CGFloat = 80
        static let avatarExtraLarge: CGFloat = 120
        
        // Icon sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
        
        // Minimum touch target
        static let minTouchTarget: CGFloat = 44
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let smooth = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
    }
}

// MARK: - View Modifiers

struct PrimaryButtonStyle: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.headlineSemibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Sizes.buttonHeight)
            .background(isEnabled ? Theme.Colors.buttonPrimary : Theme.Colors.buttonPrimary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .shadow(
                color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius,
                x: Theme.Shadows.small.x,
                y: Theme.Shadows.small.y
            )
    }
}

struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.headlineSemibold)
            .foregroundColor(Theme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Sizes.buttonHeight)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.border, lineWidth: 1.5)
            )
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            .shadow(
                color: Theme.Shadows.medium.color,
                radius: Theme.Shadows.medium.radius,
                x: Theme.Shadows.medium.x,
                y: Theme.Shadows.medium.y
            )
    }
}

// MARK: - View Extensions

extension View {
    func primaryButtonStyle(isEnabled: Bool = true) -> some View {
        self.modifier(PrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    func secondaryButtonStyle() -> some View {
        self.modifier(SecondaryButtonStyle())
    }
    
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
}

// MARK: - Convenient Static Accessors

extension Theme {
    static let accentColor = Colors.accent
    static let primaryText = Colors.primaryText
    static let secondaryText = Colors.secondaryText
    static let cardBackground = Colors.cardBackground
    static let background = Colors.background
}
