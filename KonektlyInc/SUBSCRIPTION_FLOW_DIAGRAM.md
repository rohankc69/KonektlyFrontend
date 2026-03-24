# Konektly+ Subscription Flow Diagram

## Purchase Flow

```
User taps "Subscribe Now"
         |
         v
SubscriptionManager.purchase()
         |
         v
StoreKit Product.purchase()
         |
         v
iOS Payment Sheet
(Face ID/Touch ID)
         |
         v
Transaction Verification
(Apple's servers)
         |
         v
VerificationResult.verified
         |
         v
Extract JWS representation
         |
         v
POST /api/v1/subscriptions/apple/validate/
Body: { "jws_transaction": "..." }
         |
         v
Backend validates with Apple
         |
         v
Backend updates user's subscription
         |
         v
Response: SubscriptionStatus
{
  "is_konektly_plus": true,
  "plan": "konektly_plus",
  "status": "active",
  "expires_at": "..."
}
         |
         v
Update subscriptionStatus
         |
         v
Call transaction.finish()
         |
         v
UI updates to show Plus features
```

---

## App Launch Flow

```
App Launches
     |
     v
SubscriptionManager.init()
     |
     |--- loadProduct() (background)
     |     |
     |     v
     |    Product.products(for: [productID])
     |     |
     |     v
     |    Store product + displayPrice
     |
     |--- refreshSubscriptionStatus() (background)
     |     |
     |     v
     |    GET /api/v1/subscriptions/me/
     |     |
     |     v
     |    Update subscriptionStatus
     |
     |--- listenForTransactions() (background task)
           |
           v
          Runs forever, listening to Transaction.updates
```

---

## Background Renewal Flow

```
Apple Auto-Renewal (while app closed)
         |
         v
Apple charges card
         |
         v
Apple sends webhook to backend
         |
         v
Backend receives event
         |
         |--> Updates database
         |
User opens app
         |
         v
scenePhase == .active
         |
         v
refreshSubscriptionStatus()
         |
         v
GET /api/v1/subscriptions/me/
         |
         v
Response shows updated expiry date
         |
         v
UI shows new renewal date
```

---

## Transaction.updates Flow

```
(Running in background task)
         |
         v
for await result in Transaction.updates
         |
         v
New transaction received
(renewal, restore, etc.)
         |
         v
checkVerified(result)
         |
         v
Transaction.jwsRepresentation
         |
         v
POST /api/v1/subscriptions/apple/validate/
         |
         v
Backend processes
         |
         v
Update subscriptionStatus
         |
         v
Call transaction.finish()
         |
         v
Continue listening...
```

---

## Restore Purchases Flow

```
User taps "Restore Purchases"
         |
         v
SubscriptionManager.restorePurchases()
         |
         v
AppStore.sync()
         |
         v
Apple checks purchase history
         |
         v
If valid purchases exist:
  - Transaction.updates receives them
  - Sent to backend
  - subscriptionStatus updated
         |
         v
refreshSubscriptionStatus()
         |
         v
GET /api/v1/subscriptions/me/
         |
         v
UI shows restored subscription
```

---

## Cancellation Flow

```
User taps "Manage Subscription"
         |
         v
openCancellationPage()
         |
         v
AppStore.showManageSubscriptions()
         |
         v
iOS Settings sheet appears
         |
         v
User taps "Cancel Subscription"
         |
         v
Apple processes cancellation
         |
         v
Apple sends webhook to backend
         |
         v
Backend updates status to "cancelled"
(access continues until expires_at)
         |
         v
User reopens app later
         |
         v
refreshSubscriptionStatus()
         |
         v
GET /api/v1/subscriptions/me/
         |
         v
Response: {
  "status": "cancelled",
  "is_konektly_plus": true,  // still true until expires
  "expires_at": "2026-04-23..."
}
         |
         v
UI shows "Access until [date]"
```

---

## Feature Gate Check Flow

```
User views job
     |
     v
Check SubscriptionManager.shared.isKonektlyPlus
     |
     |--- TRUE
     |     |
     |     v
     |    Show exact location
     |    job.addressDisplay
     |    job.latitude (exact)
     |    job.longitude (exact)
     |
     |--- FALSE
           |
           v
          Check job.locationIsApproximate
           |
           |--- TRUE
           |     |
           |     v
           |    Show "Approximate location"
           |    job.latitude (fuzzed ±1km)
           |    job.longitude (fuzzed ±1km)
           |    Show "Unlock with Konektly+" button
           |
           |--- FALSE
                 |
                 v
                Show job.addressDisplay
                (Business didn't request fuzz)
```

---

## State Diagram

```
┌─────────────┐
│   Free      │
│  (Initial)  │
└──────┬──────┘
       │
       │ User purchases
       v
┌─────────────┐
│   Active    │◄───────────┐
│ Konektly+   │            │
└──────┬──────┘            │
       │                   │
       │ Auto-renewal      │
       └───────────────────┘
       │
       │ User cancels
       v
┌─────────────┐
│ Cancelled   │
│(until expiry)│
└──────┬──────┘
       │
       │ Expiry date passes
       v
┌─────────────┐
│  Expired    │
│  (= Free)   │
└──────┬──────┘
       │
       │ User re-subscribes
       └──────────────────┐
                          │
                          v
                    ┌─────────────┐
                    │   Active    │
                    │ Konektly+   │
                    └─────────────┘
```

---

## UI State Mapping

```
Backend Response          iOS UI Display
────────────────          ──────────────

is_konektly_plus: false   → UpgradeView
status: "active"             (Free plan CTA)

is_konektly_plus: true    → KonektlyPlusActiveView
status: "active"             ("Active Subscription")
expires_at: future           ("Renews [date]")

is_konektly_plus: true    → KonektlyPlusActiveView
status: "cancelled"          ("Access until [date]")
expires_at: future           (Manage button)

is_konektly_plus: false   → UpgradeView
status: "expired"            ("Subscribe to unlock")
```

---

## Error Handling Flow

```
Purchase Error
     |
     ├── .userCancelled
     |     |
     |     v
     |    Do nothing (user backed out)
     |
     ├── .pending
     |     |
     |     v
     |    Wait for Transaction.updates
     |    (Ask to Buy scenario)
     |
     ├── StoreKit error
     |     |
     |     v
     |    Show: "Purchase failed. Please try again."
     |
     └── Backend validation fails
           |
           v
          Show: "Purchase successful — syncing your account."
           |
           v
          Retry on next app launch via refreshSubscriptionStatus()
```

---

## Threading Model

```
SubscriptionManager (@MainActor)
     |
     |--- All @Published properties
     |    (UI updates on main thread)
     |
     |--- purchase() - async, runs on main
     |
     |--- refreshSubscriptionStatus() - async, runs on main
     |
     |--- listenForTransactions()
          |
          v
         Task(priority: .background)
         (runs off main thread)
          |
          v
         await sendToBackend()
         (switches back to main to update @Published)
```

---

## Data Flow Summary

```
StoreKit (Apple)
       |
       v
SubscriptionManager
       |
       |--- JWS Transaction
       |         |
       |         v
       |    Backend API
       |         |
       |         v
       |    SubscriptionStatus
       |         |
       └─────────┘
       |
       v
@Published subscriptionStatus
       |
       v
SwiftUI Views
       |
       v
User Interface Updates
```

---

## Lifecycle Events

```
App State          Action
─────────          ──────

Launch            → loadProduct()
                  → refreshSubscriptionStatus()
                  → Start listenForTransactions()

Foreground        → refreshSubscriptionStatus()
(scenePhase)         (ensures latest status from backend)

Background        → listenForTransactions() continues
                  → Auto-renewal events processed

Terminate         → Transaction listener cancelled
```

---

This diagram shows the complete flow of the subscription system. Use it as a reference when debugging or explaining the system to other team members.
