# Xcode Project Configuration Checklist

Use this checklist to ensure your Xcode project is properly configured for the Konektly+ subscription feature.

---

## 1. File Organization

Ensure all new files are added to your Xcode target:

### Models
- [ ] SubscriptionModels.swift

### Managers
- [ ] SubscriptionManager.swift

### Views
- [ ] SubscriptionView.swift
- [ ] UpgradeView.swift
- [ ] KonektlyPlusActiveView.swift
- [ ] JobLocationView.swift
- [ ] SubscriptionBadge.swift

### Tests
- [ ] SubscriptionTests.swift (in test target)

### Configuration
- [ ] KonektlyInc.entitlements
- [ ] KonektlyStoreKit.storekit

---

## 2. Project Settings

### Target → Signing & Capabilities
- [ ] "In-App Purchase" capability added (or verify entitlements file is linked)
- [ ] Entitlements file: `KonektlyInc.entitlements`
- [ ] Check that file shows under "Signing & Capabilities" → "App Sandbox" or "In-App Purchase"

### Target → General
- [ ] Bundle Identifier matches App Store Connect (e.g., `com.konektly.ios`)
- [ ] Minimum Deployment Target: iOS 15.0 or higher (for StoreKit 2)

### Target → Info
- [ ] No changes needed (StoreKit doesn't require Info.plist entries)

---

## 3. Scheme Configuration (for Local Testing)

### Edit Scheme → Run → Options
- [ ] StoreKit Configuration: Select `KonektlyStoreKit.storekit`
- [ ] This enables local testing without App Store Connect

To do this:
1. Click your scheme name in Xcode toolbar
2. Select "Edit Scheme..."
3. Go to "Run" → "Options"
4. Under "StoreKit Configuration", select `KonektlyStoreKit.storekit`

---

## 4. Build Settings

### Search for "StoreKit"
- [ ] No special build settings needed

### Search for "Sandbox"
- [ ] No special build settings needed

### Verify Frameworks
- [ ] StoreKit.framework is auto-linked (no manual linking needed for iOS)

---

## 5. Code Verification

### Modified Files
- [ ] `APIClient.swift` has subscription endpoints
- [ ] `KonektlyIncApp.swift` has `SubscriptionManager` in environment
- [ ] `KonektlyIncApp.swift` has `scenePhase` onChange handler

### Verify Product ID
- [ ] Open `SubscriptionManager.swift`
- [ ] Verify `productID = "com.konektly.plus.monthly"` matches App Store Connect

---

## 6. Entitlements File

### Open KonektlyInc.entitlements
Should contain:
```xml
<key>com.apple.developer.in-app-payments</key>
<array/>
```

If you already have an entitlements file:
- [ ] Merge the in-app-payments key
- [ ] Keep existing keys (like App Groups, Push Notifications, etc.)

---

## 7. StoreKit Configuration File

### Open KonektlyStoreKit.storekit
Verify:
- [ ] Product ID: `com.konektly.plus.monthly`
- [ ] Display Price: `9.99` (or your chosen price)
- [ ] Subscription Group: "Konektly Plus"
- [ ] Period: 1 month (`P1M`)

To edit:
1. Click file in Xcode navigator
2. Visual editor appears
3. Click the subscription to edit details

---

## 8. Test Target Configuration

### SubscriptionTests.swift
- [ ] File is added to test target (not main app target)
- [ ] Import statement: `@testable import KonektlyInc`
- [ ] Verify test target name matches (might be `KonektlyIncTests`)

---

## 9. Build and Run

### Build the Project
```
Cmd+B
```
- [ ] No build errors
- [ ] No warnings (optional but recommended)

### Run in Simulator (Local Testing)
```
Cmd+R
```
- [ ] App launches
- [ ] Navigate to subscription view
- [ ] StoreKit configuration provides product info
- [ ] Can simulate purchase (no real money, no backend)

### Run Tests
```
Cmd+U
```
- [ ] All subscription tests pass
- [ ] Model decoding tests pass
- [ ] Manager tests pass

---

## 10. Device Testing (Sandbox)

### Prerequisites
- [ ] App Store Connect subscription created
- [ ] Sandbox tester account created
- [ ] Scheme StoreKit configuration set to "None" (for sandbox testing)

### On Device
- [ ] Sign out of production Apple ID
- [ ] Build and run on device
- [ ] Navigate to subscription view
- [ ] Tap "Subscribe Now"
- [ ] Sign in with sandbox account when prompted
- [ ] Complete purchase
- [ ] Verify backend receives transaction

---

## 11. Pre-Production Checklist

### Code Review
- [ ] All files reviewed
- [ ] No hardcoded test values
- [ ] Error handling in place
- [ ] Loading states handled

### Backend Integration
- [ ] Backend endpoints tested
- [ ] Webhook configured
- [ ] Sandbox environment tested
- [ ] Production environment ready

### App Store Connect
- [ ] Subscription created
- [ ] Pricing set for all regions
- [ ] Localized descriptions added
- [ ] Server notifications configured

---

## 12. TestFlight Preparation

### Archive
- [ ] Scheme set to Release
- [ ] StoreKit configuration set to "None"
- [ ] Archive builds successfully

### Upload
- [ ] Archive uploaded to App Store Connect
- [ ] Processing completes
- [ ] Available in TestFlight

### TestFlight Testing
- [ ] Internal testers can install
- [ ] Subscription purchase works
- [ ] Backend receives transactions
- [ ] Feature gating works

---

## 13. App Review Preparation

### Required Elements Present
- [ ] "Restore Purchases" button visible
- [ ] Cancellation uses Apple's UI (not custom)
- [ ] No external payment links
- [ ] Subscription terms clear
- [ ] Privacy policy mentions subscriptions

### Screenshots
- [ ] Subscription screen
- [ ] Feature comparison (free vs plus)
- [ ] Active subscription view

---

## Common Issues & Solutions

### "Product not found" in Simulator
- **Solution**: Verify StoreKit configuration file is selected in scheme

### "Product not found" on Device
- **Solution**: 
  - Check product is "Ready to Submit" in App Store Connect
  - Verify bundle ID matches exactly
  - Wait 2-24 hours after creating product

### Build errors about StoreKit
- **Solution**: 
  - Verify deployment target is iOS 15.0+
  - Clean build folder (Cmd+Shift+K)
  - Restart Xcode

### Entitlements not working
- **Solution**:
  - Check file is linked to target
  - Verify signing & capabilities shows In-App Purchase
  - Re-add capability if needed

### Tests failing
- **Solution**:
  - Verify test target name in @testable import
  - Ensure SubscriptionModels.swift is in main target
  - Clean and rebuild

---

## Quick Test Procedure

1. **Local (Simulator)**:
   - Select StoreKit configuration in scheme
   - Run app → Navigate to subscription → See product info
   
2. **Sandbox (Device)**:
   - Set StoreKit configuration to "None"
   - Run on device → Purchase with sandbox account → Verify backend sync

3. **Production (TestFlight)**:
   - Archive and upload
   - Install from TestFlight → Purchase works end-to-end

---

## Final Verification

Before submitting to App Review:
- [ ] All files committed to version control
- [ ] StoreKit configuration set to "None" in Release scheme
- [ ] Archive builds successfully
- [ ] Tested on real device with sandbox account
- [ ] Backend production environment ready
- [ ] App Store Connect product approved

---

## Additional Resources

- [Xcode Help: Adding Capabilities](https://help.apple.com/xcode/mac/current/#/dev88ff319e7)
- [Testing In-App Purchases in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)
- [StoreKit Testing Documentation](https://developer.apple.com/documentation/storekittesting)

---

Good luck with your implementation! If you encounter any issues not covered here, check the IMPLEMENTATION_SUMMARY.md and SUBSCRIPTION_SETUP.md files for more details.
