# Konektly+ Upgrade Buttons - Visual Guide

## What I Just Created

### NEW: Large Upgrade Card Component

A **prominent, feature-rich upgrade card** that shows in the Profile view.

---

## Visual Design

### The New Upgrade Card

```
┌────────────────────────────────────────────┐
│  * Konektly+                              │
│  Unlock premium features                   │
│                                            │
│  ✓ Exact job locations                    │
│  ✓ Priority support                       │
│  ✓ Advanced analytics                     │
│  ✓ Early access to new features           │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │   Upgrade Now              →         │ │  <- BIG BUTTON
│  └──────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

**Design Features:**
- Gradient blue background
- Gold star icon
- 4 feature bullets with checkmarks
- Large "Upgrade Now" button with arrow
- Gradient border
- Drop shadow
- Takes full width

---

## Where It Shows

### Profile View

```
[Profile Header]
   |
   v
┌─────────────────────────┐
│ * Konektly+            │
│ Unlock premium features │
│                         │
│ ✓ Exact job locations  │  <- THIS IS THE NEW CARD
│ ✓ Priority support     │
│ ✓ Advanced analytics   │
│ ✓ Early access         │
│                         │
│ [ Upgrade Now →  ]     │  <- CLEAR BUTTON
└─────────────────────────┘
   |
   v
[Availability Toggle]
   |
   v
[Bio Section]
   |
   v
[Settings]
  - * Upgrade to Konektly+  <- Also here
```

---

## Components Created

### 1. UpgradeCard (NEW)
**File:** `SubscriptionPromptComponents.swift`

**What it does:**
- Shows 4 premium features
- Big "Upgrade Now" button
- Gradient background and border
- Most prominent upgrade option

**Usage:**
```swift
UpgradeCard {
    // Open subscription sheet
    showSubscription = true
}
```

### 2. FeatureBullet (NEW)
**File:** `SubscriptionPromptComponents.swift`

**What it does:**
- Checkmark icon
- Feature text
- Clean, readable layout

**Usage:**
```swift
FeatureBullet(text: "Exact job locations")
```

### 3. SubscriptionInlineBanner (Existing - Updated)
**File:** `SubscriptionPromptComponents.swift`

**What it does:**
- Smaller, subtle banner option
- Used in settings/secondary locations

---

## Button Hierarchy

### Primary (Most Visible)
**UpgradeCard** in Profile
- Large card with features
- Big button
- Main conversion point

### Secondary
**Settings Row** - "Upgrade to Konektly+"
- Always accessible
- Alternative path

### Tertiary (Contextual)
**Job Cards** - Location unlock buttons
- Only on approximate locations
- Contextual trigger

---

## Theme Compliance

All new components use your theme system:

### Colors
```swift
Theme.Colors.accent         // Professional blue
Theme.Colors.primaryText    // Label color
Theme.Colors.secondaryText  // Secondary label
```

### Typography
```swift
Theme.Typography.title2           // Card title
Theme.Typography.headlineSemibold // Button text
Theme.Typography.subheadline      // Features
```

### Spacing
```swift
Theme.Spacing.lg    // Card padding
Theme.Spacing.md    // Button padding
Theme.Spacing.sm    // Feature spacing
```

### Corner Radius
```swift
Theme.CornerRadius.large   // Card corners
Theme.CornerRadius.medium  // Button corners
```

### Shadows
```swift
Theme.Shadows.medium  // Card shadow
```

---

## Features Displayed

### 1. Exact Job Locations
Workers see precise addresses, businesses share exact locations

### 2. Priority Support
Faster response times, dedicated service

### 3. Advanced Analytics
Performance tracking, earnings reports

### 4. Early Access
New features first, beta programs

---

## User Flow

1. User opens Profile tab
2. Sees large upgrade card (impossible to miss)
3. Reads 4 benefits
4. Taps "Upgrade Now" button
5. Sheet opens with pricing
6. Subscribes

---

## Code Changes

### ProfileView.swift
```swift
// OLD: Just a banner
if !subscriptionManager.isKonektlyPlus {
    SubscriptionInlineBanner { ... }
}

// NEW: Large featured card with button
if !subscriptionManager.isKonektlyPlus {
    UpgradeCard {
        showSubscription = true
    }
}
```

### SubscriptionPromptComponents.swift
Added two new components:
1. `UpgradeCard` - Large featured card
2. `FeatureBullet` - Checkmark + text

---

---

## Testing

Run the app and:

1. Go to Profile tab
2. You should see a large blue card
3. With "Konektly+" title
4. 4 feature bullets
5. Big "Upgrade Now" button

If you're already subscribed:
- Card won't show
- Look for "Konektly+" badge on avatar

---

---

Last Updated: March 24, 2026
Files Changed:
- SubscriptionPromptComponents.swift (added UpgradeCard + FeatureBullet)
- ProfileView.swift (added UpgradeCard usage)
