# Konektly+ Subscription Access Points

## Overview
This document lists all the places in the app where users (workers) can discover and upgrade to Konektly+.

## Date: March 24, 2026

---

## Access Points Summary

### Always Available
1. **Profile View** - Persistent access point
2. **Settings Menu** - Direct subscription management

### Contextual (When Relevant)
3. **Job Cards with Approximate Locations** - Shown only when `locationIsApproximate == true`
4. **Map View** - Location blur prompts on relevant jobs

---

## Profile View (PRIMARY - Always Visible)

### Location
`ProfileView.swift`

### Components

#### A. Subscription Banner (Inline)
**When Shown:** 
- User is a **worker** (`userRole == .worker`)
- User is **NOT** subscribed (`!subscriptionManager.isKonektlyPlus`)

**Visual Design:**
- Full-width gradient banner
- Konektly+ branding with icon
- "Unlock exact job locations" text
- Chevron indicating it's tappable

**Code Location:** Line 146-151
```swift
if userRole == .worker && !subscriptionManager.isKonektlyPlus {
    SubscriptionInlineBanner {
        showSubscription = true
    }
    .padding(.horizontal, Theme.Spacing.lg)
}
```

#### B. Settings Row
**When Shown:**
- User is a **worker** (`userRole == .worker`)
- Shows for both subscribers and non-subscribers

**Text:**
- Non-subscribers: "Konektly+"
- Subscribers: "Konektly+ Active"

**Code Location:** Line 203-211
```swift
if userRole == .worker {
    SettingsRow(
        icon: "star.circle.fill",
        title: subscriptionManager.isKonektlyPlus ? "Konektly+ Active" : "Konektly+",
        showChevron: true
    ) {
        showSubscription = true
    }
    Divider().padding(.leading, 52)
}
```

#### C. Active Subscription Badge
**When Shown:**
- User **IS** subscribed (`subscriptionManager.isKonektlyPlus`)

**Visual Design:**
- Small badge on profile avatar
- Checkmark icon + "Konektly+" text
- Gradient background

**Code Location:** Line 45-48
```swift
if subscriptionManager.isKonektlyPlus {
    ActiveSubscriptionBadge()
        .offset(y: 20)
}
```

---

## Map View Job Cards (CONTEXTUAL)

### Location
`MapHomeView.swift` - `NearbyJobCardView`

### When Shown
- Job has `locationIsApproximate == true`
- User is **NOT** subscribed (`!subscriptionManager.isKonektlyPlus`)

### Components

#### A. Tappable Location Icon
**Visual Design:**
- Small `location.circle` icon next to address
- Accent color (clickable)
- Tapping opens subscription sheet

**Code Location:** Line 383-391
```swift
if job.locationIsApproximate == true && !subscriptionManager.isKonektlyPlus {
    Button {
        showSubscription = true
    } label: {
        Image(systemName: "location.circle")
            .font(.system(size: 14))
            .foregroundColor(Theme.Colors.accent)
    }
}
```

#### B. Location Blur Prompt
**Visual Design:**
- Inline banner below job details
- "Approximate location" text with eye-slash icon
- "Unlock" button with lock icon
- Subtle gradient background

**Code Location:** Line 407-411
```swift
if job.locationIsApproximate == true && !subscriptionManager.isKonektlyPlus {
    LocationBlurPrompt {
        showSubscription = true
    }
}
```

**What It Shows:**
- For **subscribers**: Only the gray location.circle icon (read-only)
- For **non-subscribers**: Clickable upgrade prompts

---

## Shifts View Job Cards (CONTEXTUAL)

### Location
`ShiftsView.swift` - `NearbyJobListCard`

### When Shown
Same triggers as Map View:
- Job has `locationIsApproximate == true`
- User is **NOT** subscribed

### Components
Identical to Map View:
- Tappable location icon (Line 410-418)
- Location blur prompt banner (Line 445-449)

**Why Duplicate?**
- Consistency across all job viewing contexts
- Workers may browse jobs in either Map or List view

---

## Business Users

### Access
Businesses do **NOT** see Konektly+ prompts because:
- Subscription is worker-only feature
- Businesses can already see exact locations for their own jobs
- Prevents confusion and irrelevant upsells

### Code Protection
```swift
if userRole == .worker && !subscriptionManager.isKonektlyPlus {
    // Only workers see upgrade prompts
}
```

---

## Testing the Access Points

### Test Scenario 1: Non-Subscribed Worker
**Steps:**
1. Sign in as worker
2. Navigate to Profile → Should see **Subscription Banner** and **Settings Row**
3. Browse jobs → Should see upgrade prompts on jobs with approximate locations
4. Tap any prompt → Should open SubscriptionView

**Expected Result:** 3+ access points visible

### Test Scenario 2: Subscribed Worker
**Steps:**
1. Sign in as subscribed worker (simulate via backend or sandbox)
2. Navigate to Profile → Should see **Active Badge** and **Settings Row** (text: "Konektly+ Active")
3. Browse jobs → Should NOT see upgrade prompts (only read-only icons)

**Expected Result:** Upgrade prompts hidden, management options shown

### Test Scenario 3: Business User
**Steps:**
1. Sign in as business
2. Navigate to Profile → Should NOT see subscription banner or row
3. Post jobs with approximate locations → Should NOT see upgrade prompts

**Expected Result:** No subscription UI shown

---

## User Journey

### Discovery Path (Non-Subscriber)
```
1. Worker browses jobs
   ↓
2. Sees "Approximate location" with lock icon
   ↓
3. Taps "Unlock" button
   ↓
4. Opens SubscriptionView with pricing
   ↓
5. Purchases subscription
   ↓
6. Returns to job → Now sees exact location
```

### Alternative Discovery
```
1. Worker visits Profile
   ↓
2. Sees prominent Konektly+ banner
   ↓
3. Taps banner
   ↓
4. Opens SubscriptionView
```

---

## Visual Hierarchy

### Primary (Always Visible)
- **Profile Banner**: Most prominent, persistent discovery
- **Settings Row**: Always accessible for management

### Secondary (Contextual)
- **Job Card Prompts**: Only shown when relevant (approximate locations)
- **Map Pins**: Visual indicator of approximate vs. exact

### Tertiary (Status)
- **Active Badge**: Confirms subscription status

---

## Why You Might Not See It

### Common Reasons

1. **Wrong User Role**
   - Solution: Ensure `userRole == .worker`
   - Check: `@AppStorage("userRole")` should be "worker"

2. **Already Subscribed**
   - Solution: Check `subscriptionManager.isKonektlyPlus`
   - Debug: Print subscription status in console

3. **No Approximate Locations**
   - Solution: Backend needs to return `location_is_approximate: true`
   - Test: Mock a job with this field set

4. **SubscriptionManager Not Loading**
   - Solution: Check StoreKit configuration
   - Debug: Verify product ID matches App Store Connect

---

## Debugging Checklist

### Step 1: Check User Role
```swift
// Add to ProfileView or ShiftsView
.onAppear {
    print("User Role: \(userRole)")
    print("Is Konektly+: \(subscriptionManager.isKonektlyPlus)")
}
```

### Step 2: Check Subscription Status
```swift
// Add to SubscriptionManager
func debug() {
    print("Subscription Status: \(subscriptionStatus?.plan ?? "nil")")
    print("Is Konektly Plus: \(isKonektlyPlus)")
    print("StoreKit Product: \(storeKitProduct?.displayName ?? "not loaded")")
}
```

### Step 3: Check Job Data
```swift
// Add to job card view
.onAppear {
    print("Job \(job.id) - locationIsApproximate: \(job.locationIsApproximate ?? false)")
}
```

### Step 4: Force Trigger
```swift
// Add a test button to ProfileView
Button("TEST: Open Subscription") {
    showSubscription = true
}
```

---

## Expected Behavior by Platform

### iOS Simulator
- StoreKit products may not load (use .storekit configuration file)
- Subscription status should still show UI based on mock data

### TestFlight
- Real StoreKit products load
- Sandbox Apple ID required for testing purchases

### Production
- All access points functional
- Real purchases processed

---

## Metrics to Track

### Discovery Metrics
1. **Banner Impressions**: How many times users see the profile banner
2. **Contextual Prompt Taps**: Taps on job card unlock buttons
3. **Settings Row Taps**: Access via settings menu

### Conversion Metrics
1. **Banner → Purchase**: Users who subscribe from profile banner
2. **Job Card → Purchase**: Users who subscribe from contextual prompts
3. **Overall Conversion Rate**: Percentage of free users who upgrade

### Retention Metrics
1. **Subscription Renewals**: Auto-renew rate
2. **Cancellation Rate**: Users who cancel after trial/first month

---

## State Management

### SubscriptionManager Properties
```swift
@Published var subscriptionStatus: SubscriptionStatus?
@Published var storeKitProduct: Product?
@Published var isPurchasing = false
@Published var error: String?

// Computed
var isKonektlyPlus: Bool
var displayPrice: String
```

### View State
```swift
@State private var showSubscription = false
@StateObject private var subscriptionManager = SubscriptionManager.shared
```

---

## Known Issues & Solutions

### Issue 1: "Upgrade prompts not showing"
**Cause:** User is already considered subscribed (cached state)
**Solution:** 
```swift
// Clear subscription cache
await subscriptionManager.refreshSubscriptionStatus()
```

### Issue 2: "StoreKit product not loading"
**Cause:** Product ID mismatch or App Store Connect not configured
**Solution:**
1. Verify `productID = "com.konektly.plus.monthly"` in SubscriptionManager
2. Check App Store Connect for matching product
3. Ensure StoreKit configuration file in Xcode project

### Issue 3: "Prompts show but button doesn't work"
**Cause:** Sheet binding not triggering
**Solution:**
```swift
// Ensure showSubscription is properly set
Button {
    print("DEBUG: Opening subscription")
    showSubscription = true
} label: {
    Text("Unlock")
}
```

---

## Summary

### Where Users CAN See Konektly+

1. **Profile View** (always) - Banner + Settings Row
2. **Job Cards** (contextual) - When location is approximate
3. **Map View** (contextual) - Location blur prompts

### Where Users CANNOT See Konektly+

1. Business users (wrong role)
2. Already subscribed users (prompts hidden)
3. Jobs without location blurring (not relevant)

### Primary Discovery Path

**Profile Banner → SubscriptionView → Purchase**

This is the most discoverable and persistent access point.

---

**Last Updated:** March 24, 2026
**Version:** 1.0
