# Konektly+ Subscription Implementation Guide

## Overview
Konektly+ is an auto-renewable subscription that unlocks exact job locations for workers. The implementation uses StoreKit 2 (iOS 15+) and integrates with your existing backend API.

---

## Files Created

### Models & Business Logic
- **SubscriptionModels.swift**: Backend subscription models (`SubscriptionStatus`, `AppleValidateRequest`)
- **SubscriptionManager.swift**: StoreKit 2 manager (single source of truth for subscription state)

### UI Components
- **SubscriptionView.swift**: Main subscription view (routes to upgrade or active view)
- **UpgradeView.swift**: Upgrade screen for free users
- **KonektlyPlusActiveView.swift**: Active subscription screen
- **JobLocationView.swift**: Example component showing feature gating

### Configuration
- **KonektlyInc.entitlements**: In-app purchase entitlement
- **APIClient.swift**: Added subscription endpoints
- **KonektlyIncApp.swift**: Added subscription manager and foreground refresh

---

## Setup Instructions

### 1. Xcode Configuration

#### Add Entitlements File
1. Open your Xcode project
2. Select your target
3. Go to "Signing & Capabilities"
4. If you already have an entitlements file, merge it with `KonektlyInc.entitlements`
5. If not, ensure the entitlements file is added to your target

#### Update Product ID
In `SubscriptionManager.swift`, verify the product ID matches your App Store Connect configuration:
```swift
private let productID = "com.konektly.plus.monthly"
```

---

### 2. App Store Connect Setup

#### Create Subscription
1. Go to App Store Connect
2. Select your app
3. Navigate to **Monetization → Subscriptions**
4. Click **+** to create a new subscription group (if needed)
5. Add a new subscription with:
   - **Product ID**: `com.konektly.plus.monthly`
   - **Name**: Konektly+ Monthly
   - **Price**: Set your price tier
   - **Billing Period**: 1 month
   - **Auto-renewable**: Yes

#### Configure App Store Server Notifications
1. In App Store Connect, go to **App Information**
2. Scroll to **App Store Server Notifications**
3. Enter your backend URL: `https://api.konektly.com/api/v1/subscriptions/apple/webhook/`
4. This allows Apple to notify your backend of subscription events (renewals, cancellations, etc.)

---

### 3. Backend Configuration

Ensure your backend has:
- **Product ID configured**: `APPLE_PRODUCT_ID_KONEKTLY_PLUS = "com.konektly.plus.monthly"`
- **Environment**: Set `APPLE_ENVIRONMENT=sandbox` for testing, `production` for live

#### Required Backend Endpoints
- `POST /api/v1/subscriptions/apple/validate/` - Validates JWS transaction from iOS
- `GET /api/v1/subscriptions/me/` - Returns current subscription status
- Apple webhook handler (backend only, not called from iOS)

---

### 4. Testing

#### Sandbox Testing
1. In App Store Connect, go to **Users and Access → Sandbox Testers**
2. Create a sandbox Apple ID
3. On your test device:
   - Sign out of your production Apple ID in Settings
   - When prompted during purchase, sign in with sandbox Apple ID
4. Sandbox subscriptions renew every few minutes instead of monthly

#### Test Flows
- **Purchase**: Tap "Subscribe Now" in UpgradeView
- **Restore**: Tap "Restore Purchases" (required by App Store guidelines)
- **Manage/Cancel**: Tap "Manage Subscription" → redirects to App Store settings
- **Auto-renewal**: Subscription renews automatically (check after a few minutes in sandbox)
- **Foreground refresh**: Background app, then reopen → subscription status refreshes

---

## Integration Examples

### Adding Subscription to Navigation

Add to your profile/account view:
```swift
NavigationLink {
    SubscriptionView()
        .navigationTitle("Konektly+")
} label: {
    HStack {
        Image(systemName: "star.fill")
        Text("Subscription")
        Spacer()
        if SubscriptionManager.shared.isKonektlyPlus {
            Text("Active")
                .foregroundStyle(Theme.Colors.success)
        }
    }
}
```

### Feature Gating in Job Views

Use the pattern from `JobLocationView.swift`:
```swift
if SubscriptionManager.shared.isKonektlyPlus {
    // Show exact location
    Text(job.addressDisplay ?? "")
} else {
    // Show approximate location
    if job.locationIsApproximate {
        Text("Approximate location")
        Button("Unlock exact location") {
            showSubscriptionSheet = true
        }
    }
}
```

### Job List Distance Display
```swift
if SubscriptionManager.shared.isKonektlyPlus {
    Text("\(job.distanceKm, specifier: "%.1f") km")
} else if job.locationIsApproximate {
    Text("~\(job.distanceKm, specifier: "%.0f") km")
}
```

---

## Important Rules

### DO:
- Always call `transaction.finish()` after processing
- Listen to `Transaction.updates` for background renewals
- Call `refreshSubscriptionStatus()` when app becomes active
- Show "Restore Purchases" button (App Store requirement)
- Use `AppStore.showManageSubscriptions()` for cancellation

### DO NOT:
- Call backend `/subscriptions/cancel/` from iOS - Apple manages billing
- Call backend `/subscriptions/checkout/` from iOS - that's for web/Stripe
- Skip `transaction.finish()` - Apple will re-deliver forever
- Show external payment options or mention pricing outside IAP
- Create custom cancellation UI that bypasses Apple

---

## Troubleshooting

### "Could not load subscription details"
- Verify product ID matches App Store Connect exactly
- Ensure subscription is approved (or in "Ready to Submit" state)
- Check bundle ID matches

### Purchase succeeds but backend sync fails
- Transaction is stored by StoreKit and will retry on next launch
- User sees: "Purchase successful — syncing your account. Please wait."
- Automatic recovery via `refreshSubscriptionStatus()` on next app open

### Subscription not refreshing
- Verify `scenePhase` onChange is in place (KonektlyIncApp.swift)
- Check network connectivity
- Backend might be returning cached status - verify backend logs

### App Store rejection
- Ensure "Restore Purchases" button is visible
- Cancellation MUST use `AppStore.showManageSubscriptions()`
- No external payment links or mentions of web pricing

---

## Files Modified

### KonektlyIncApp.swift
- Added `SubscriptionManager` to environment
- Added foreground refresh on `scenePhase` change

### APIClient.swift
- Added subscription endpoint definitions
- Added `validateAppleTransaction()` and `fetchSubscriptionStatus()` methods

---

## Next Steps

1. Configure product in App Store Connect
2. Test purchase flow with sandbox account
3. Integrate `JobLocationView` pattern into your job detail/card views
4. Add subscription navigation link to profile/account screen
5. Submit for App Review once tested

---

## Support

For backend integration questions, refer to your backend team's subscription API documentation.
For StoreKit questions, see Apple's documentation:
- https://developer.apple.com/documentation/storekit
- https://developer.apple.com/in-app-purchase/
