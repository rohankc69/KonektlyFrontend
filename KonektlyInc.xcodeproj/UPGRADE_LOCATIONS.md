# Konektly+ Upgrade Locations

## Summary
Konektly+ is now available for BOTH workers AND businesses (like Uber One).

---

## Where Users Can Upgrade

### 1. Profile View - PRIMARY LOCATION

**Location:** Profile tab (both workers and businesses)

**Components:**

#### A. Upgrade Banner (Top of Profile)
- **Visibility:** Shows for ALL non-subscribers (workers and businesses)
- **Position:** Right after profile header, before bio section
- **Design:** 
  - Large gradient banner with star icon
  - "Upgrade to Konektly+" headline
  - "Get premium features and priority support" subtitle
  - Tappable, opens subscription sheet
- **Code:** ProfileView.swift, line ~145

#### B. Settings Row
- **Visibility:** Shows for ALL users
- **Position:** First item in settings list
- **Text:** 
  - Non-subscribers: "Upgrade to Konektly+"
  - Subscribers: "Konektly+ Active"
- **Design:** Star icon with chevron
- **Code:** ProfileView.swift, line ~200

---

### 2. Job Cards - CONTEXTUAL

**Location:** Jobs with approximate locations

**Who Sees It:**
- Workers viewing jobs with `locationIsApproximate: true`
- Only non-subscribers

**Components:**
- Tappable location icon (accent blue)
- "Unlock" button in location blur prompt

**Files:**
- MapHomeView.swift (map bottom sheet)
- ShiftsView.swift (list view)

---

## What Users See

### Non-Subscribers (Workers & Businesses)

**Profile Tab:**
```
[Profile Header]
   |
   v
[Upgrade to Konektly+ Banner] <- BIG, VISIBLE
   |
   v
[Bio Section]
   |
   v
[Settings]
  - Edit Profile
  - Upgrade to Konektly+ <- Also here
  - Notifications
  - ...
```

### Subscribers

**Profile Tab:**
```
[Profile Header with Konektly+ Badge]
   |
   v
[NO BANNER - Already subscribed]
   |
   v
[Bio Section]
   |
   v
[Settings]
  - Edit Profile
  - Konektly+ Active <- Manage subscription
  - Notifications
  - ...
```

---

## Benefits Shown

### For Both Workers and Businesses:

1. **Exact Job Locations**
   - Workers: See precise addresses
   - Businesses: Share exact locations with hired workers

2. **Priority Support**
   - Faster response times
   - Dedicated customer service

3. **Advanced Analytics**
   - Track performance and earnings
   - Detailed reports

4. **Early Access**
   - New features first
   - Beta programs

---

## Testing

### To See the Upgrade Banner:

1. Open the app
2. Go to Profile tab
3. Should see the upgrade banner right below your profile stats

### If You Don't See It:

Check if you're already subscribed:
- Look for "Konektly+" badge on your avatar
- Check settings row - does it say "Konektly+ Active"?

---

## Code Changes Made

### ProfileView.swift

**Before:**
```swift
// Only showed for workers
if userRole == .worker && !subscriptionManager.isKonektlyPlus {
    SubscriptionInlineBanner { ... }
}
```

**After:**
```swift
// Shows for everyone (workers AND businesses)
if !subscriptionManager.isKonektlyPlus {
    SubscriptionInlineBanner { ... }
}
```

### SubscriptionPromptComponents.swift

**Updated banner text:**
- Icon: star.circle.fill (instead of mappin)
- Title: "Upgrade to Konektly+"
- Subtitle: "Get premium features and priority support"

### UpgradeView.swift

**Updated benefits to include both user types:**
- Exact job locations (workers + businesses)
- Priority support
- Advanced analytics
- Early access

---

## Visual Design

### Banner Appearance:
```
┌──────────────────────────────────────────┐
│  *  Upgrade to Konektly+              › │
│      Get premium features and support    │
└──────────────────────────────────────────┘
```

- Gradient blue background (accent color opacity)
- Star icon in circle
- Bold headline
- Subtle subtitle
- Chevron indicates it's tappable

---

## User Flow

1. User opens Profile
2. Sees upgrade banner (if not subscribed)
3. Taps banner
4. Sheet opens with UpgradeView
5. Shows 4 premium benefits
6. Price displayed (from StoreKit)
7. "Subscribe Now" button
8. "Restore Purchases" option

---

Last Updated: March 24, 2026
