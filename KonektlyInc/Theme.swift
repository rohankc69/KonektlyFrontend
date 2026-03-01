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
        // Primary colors - adaptive for light/dark mode
        static let primary = Color.primary // Adapts automatically
        static let secondary = Color.secondary // Adapts automatically
        static let accent = Color(red: 0.0, green: 0.8, blue: 0.4) // Green accent
        
        // Background colors - adaptive
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
        
        // Text colors - adaptive for dark mode
        static let primaryText = Color(UIColor.label) // Adapts to dark mode
        static let secondaryText = Color(UIColor.secondaryLabel) // Adapts to dark mode
        static let tertiaryText = Color(UIColor.tertiaryLabel) // Adapts to dark mode
        
        // Functional colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let urgent = Color.red
        
        // Card and surface colors - adaptive
        static let cardBackground = Color(UIColor.secondarySystemBackground) // Better contrast in dark mode
        static let overlayBackground = Color(UIColor.systemBackground).opacity(0.95)
        
        // Border and separator - adaptive
        static let border = Color(UIColor.separator)
        static let divider = Color(UIColor.separator)
        
        // Map overlay colors - work in both modes
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
        static let buttonHeight: CGFloat = 52
        static let smallButtonHeight: CGFloat = 40
        
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
            .background(isEnabled ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.5))
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
            .background(Color.white)
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
