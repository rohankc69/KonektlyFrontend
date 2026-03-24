# Konektly - On-Demand Staffing App

## Project Overview
A production-ready SwiftUI iOS app inspired by Uber's sleek interface, designed for connecting businesses with on-demand workers for short-term shifts. Built for iOS 26.2 with support for iPhone 17 Pro.

## Features Implemented

### Core Screens

1. **Role Selection (Onboarding)**
   - Elegant animated onboarding flow
   - Choice between Business and Worker roles
   - Persisted using `@AppStorage`
   - Smooth transitions and haptic feedback

2. **Map Home View**
   - Full-screen MapKit integration
   - Real-time pins for shifts/workers based on user role
   - iOS-style search bar with filter chips
   - Floating action button ("Post a Job" / "Find Work")
   - Bottom sheet with three detents (collapsed/medium/large)
   - Interactive map annotations with selection states

3. **Shifts View**
   - Segmented control for shift status (Available/Applied/Completed)
   - Searchable shift list
   - Role-specific content (Workers see shifts, Businesses see jobs)
   - Status badges and worker assignments

4. **Messages View**
   - Clean conversation list
   - Real-time-style chat interface
   - Message bubbles with timestamps
   - Unread count badges
   - Send/receive message functionality

5. **Profile View**
   - Large avatar with verification badges
   - Star ratings and completed shifts counter
   - Availability toggle for workers
   - Skills display with flow layout
   - Settings list with navigation
   - Logout functionality

### Design System (Theme.swift)

- **Colors**: Uber-inspired black/white palette with green accent
- **Typography**: SF Font throughout (largeTitle, headline, body, caption)
- **Spacing**: Consistent 4-8-12-16-20-24-32-40pt scale
- **Corner Radius**: 8-12-16-20pt variants
- **Shadows**: Small/medium/large elevation system
- **Button Styles**: Primary (filled) and Secondary (outlined)
- **Card Style**: Rounded corners with shadow

### Reusable Components

- **ShiftCardView**: Displays shift details with role-specific CTAs
- **WorkerCardView**: Shows worker profiles with availability status
- **ConversationRow**: Message preview in chat list
- **MessageBubble**: Chat message with sender differentiation
- **EmptyStateView**: Generic empty state with icon/title/subtitle
- **FilterChipView**: Pill-shaped filter buttons
- **MapPinView**: Custom map annotation with urgency indicator
- **StatView**: Profile statistics display
- **SettingsRow**: List row with icon and chevron

### Data Architecture

**Models.swift**
- `User`: Role-based user with ratings, skills, verification
- `Shift`: Job posting with time, location, requirements
- `Worker`: Available worker profiles
- `Message` & `Conversation`: Chat system
- `Location`: Coordinate wrapper with address

**MockData.swift**
- Sample users, shifts, workers, locations (San Francisco area)
- Realistic mock conversations and messages
- Current user profile

### Navigation Structure

```
TabView (AppRootView)
├── Map (MapHomeView)
│   └── NavigationStack
├── Shifts (ShiftsView)
│   └── NavigationStack
├── Messages (MessagesView)
│   └── NavigationStack
│       └── ChatView
└── Profile (ProfileView)
    └── NavigationStack
```

## iOS Features Utilized

- **SwiftUI Sheets**: `.presentationDetents([.height(120), .medium, .large])`
- **MapKit**: Interactive map with custom annotations
- **@AppStorage**: Persistent role selection
- **NavigationStack**: Modern iOS navigation
- **TabView**: Standard tab bar interface
- **Haptic Feedback**: `UIImpactFeedbackGenerator` for button presses
- **SF Symbols**: Consistent iconography
- **Dynamic Type**: Accessibility-ready typography

## Project Structure

```
KonektlyInc/
├── Models.swift              # Data models
├── MockData.swift            # Sample data
├── Theme.swift               # Design system
├── RolePickerView.swift      # Onboarding
├── AppRootView.swift         # Tab navigation
├── MapHomeView.swift         # Map + bottom sheet
├── ShiftCardView.swift       # Shift card component
├── WorkerCardView.swift      # Worker card component
├── ShiftsView.swift          # Shifts list
├── MessagesView.swift        # Chat list + thread
├── ProfileView.swift         # User profile
├── ContentView.swift         # Root view
└── KonektlyIncApp.swift      # App entry point
```

## Build Status

**BUILD SUCCEEDED** on iPhone 17 Pro Simulator (iOS 26.2)

All files compile without errors. The app is ready to run.

## Visual Design Highlights

- **Uber-like Aesthetic**: Minimal black/white with strategic green accents
- **Modern iOS**: Rounded cards, smooth shadows, native components
- **Accessibility**: Dynamic Type support, VoiceOver labels
- **Animations**: Smooth transitions, spring animations, detent changes
- **Touch Targets**: Minimum 44pt for accessibility compliance

## Key Implementation Details

1. **No Backend**: All data is local/mock - perfect for UI prototyping
2. **No Third-Party Libraries**: Pure SwiftUI + Apple frameworks
3. **Role-Based UI**: Different content for Business vs Worker roles
4. **Production-Ready Code**: Clean architecture, reusable components
5. **Apple HIG Compliant**: Follows Human Interface Guidelines

## User Flows

### Worker Flow
1. Select "I'm a Worker" on onboarding
2. View map with available shift pins
3. Browse shifts in bottom sheet
4. Accept shifts with CTAs
5. Chat with businesses
6. Toggle availability in profile

### Business Flow
1. Select "I'm a Business" on onboarding
2. View map with available worker pins
3. Browse workers in bottom sheet
4. Invite workers to shifts
5. Chat with workers
6. Post new jobs

## Next Steps (Future Enhancements)

- Location permissions and real user location
- Backend integration for real-time data
- Push notifications for messages/shifts
- Calendar integration for scheduling
- Payment processing
- Rating and review system
- Photo uploads for profiles
- Advanced filtering and search

---

**Built with SwiftUI for iOS 26.2**
