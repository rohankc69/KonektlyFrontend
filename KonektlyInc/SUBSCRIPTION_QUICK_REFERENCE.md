# Konektly+ Quick Reference

## Feature Gating Pattern

### Check Subscription Status
```swift
if SubscriptionManager.shared.isKonektlyPlus {
    // Show premium features
} else {
    // Show limited features + upgrade CTA
}
```

### Use in Job Views
```swift
// Address display
if SubscriptionManager.shared.isKonektlyPlus {
    Text(job.addressDisplay ?? "Address not available")
} else if job.locationIsApproximate {
    Text("Approximate location")
}

// Distance display
if SubscriptionManager.shared.isKonektlyPlus {
    Text("\(job.distanceKm, specifier: "%.1f") km")
} else if job.locationIsApproximate {
    Text("~\(job.distanceKm, specifier: "%.0f") km")
}
```

---

## UI Components

### Subscription View (Full Screen)
```swift
NavigationLink {
    SubscriptionView()
        .navigationTitle("Konektly+")
} label: {
    Text("Manage Subscription")
}
```

### Subscription Badge (Profile Header)
```swift
HStack {
    Text(user.name)
    SubscriptionBadge() // Shows "Konektly+" badge if active
}
```

### Promo Badge (Settings/Profile)
```swift
SubscriptionPromoBadge {
    showSubscriptionSheet = true
}
```

### Upgrade Sheet (From Any View)
```swift
.sheet(isPresented: $showSubscriptionSheet) {
    NavigationStack {
        SubscriptionView()
            .navigationTitle("Konektly+")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSubscriptionSheet = false }
                }
            }
    }
}
```

---

## Backend Integration

### Job Response Fields
```json
{
  "location_is_approximate": true,   // true for free users
  "address_display": null,           // null for free users
  "latitude": 43.6532,               // fuzzed ±1km for free users
  "longitude": -79.3832,             // fuzzed ±1km for free users
  "distance_km": 5.2,                // approximate for free users
  "distance_m": 5200                 // approximate for free users
}
```

### Subscription Status Response
```json
{
  "plan": "konektly_plus",           // "free" | "konektly_plus"
  "plan_display": "Konektly+",
  "status": "active",                // "active" | "cancelled" | "expired"
  "status_display": "Active",
  "is_konektly_plus": true,          // USE THIS for feature gates
  "expires_at": "2026-04-23T12:00:00Z",
  "started_at": "2026-03-23T12:00:00Z"
}
```

---

## Key Rules

### DO:
- Use `SubscriptionManager.shared.isKonektlyPlus` for all feature gates
- Show "Restore Purchases" button (App Store requirement)
- Handle approximate locations gracefully for free users
- Refresh subscription on app foreground (already implemented)

### DO NOT:
- Call backend `/subscriptions/cancel/` from iOS
- Call backend `/subscriptions/checkout/` from iOS (Stripe/web only)
- Skip `transaction.finish()` in custom StoreKit code
- Show external payment links

---

## Testing Checklist

- [ ] Purchase subscription with sandbox account
- [ ] Restore purchases
- [ ] Cancel subscription (through App Store settings)
- [ ] Verify cancelled subscription shows "Access until [date]"
- [ ] Verify exact locations appear for Plus users
- [ ] Verify approximate locations for free users
- [ ] App foreground refresh works
- [ ] Badge appears in profile when Plus active

---

## Product ID
`com.konektly.plus.monthly`

Must match in:
- App Store Connect
- `SubscriptionManager.swift`
- Backend `APPLE_PRODUCT_ID_KONEKTLY_PLUS`

---

## Files to Edit for Integration

1. **Job Detail View**: Add `JobLocationView` or similar pattern
2. **Job Card View**: Show lock icon if location is approximate
3. **Profile/Settings**: Add `SubscriptionPromoBadge` or navigation link
4. **Profile Header**: Optionally add `SubscriptionBadge`

---

## Support Links

- [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [In-App Purchase Guidelines](https://developer.apple.com/in-app-purchase/)
- Backend API: `https://api.konektly.com/api/v1/subscriptions/`
