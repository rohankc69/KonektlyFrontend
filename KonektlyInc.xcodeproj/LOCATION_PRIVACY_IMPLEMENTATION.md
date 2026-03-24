# Location Privacy & Blurring Implementation

## Overview
This document outlines the location privacy and blurring feature implementation for the Konektly platform. This feature allows job locations to be displayed with approximate coordinates for privacy protection while maintaining useful distance and mapping functionality.

## Date: March 23, 2026

---

## Core Changes

### 1. APIJob Model Updates (`AuthModels.swift`)

Added three new optional properties to the `APIJob` struct to support location privacy:

```swift
/// Optional coordinates for the job location (may be approximate if locationIsApproximate is true)
let lat: Double?
let lng: Double?

/// Indicates whether the coordinates are blurred/approximate for privacy
/// When true, lat/lng represent an approximate location (e.g., offset by 100-500m)
let locationIsApproximate: Bool?
```

**New Computed Property:**
```swift
/// Returns the coordinate for map display.
/// If lat/lng are available, use them; otherwise returns nil.
var coordinate: CLLocationCoordinate2D? {
    guard let lat = lat, let lng = lng else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
}
```

### 2. CodingKeys Updates

Added to support API serialization/deserialization:
```swift
case lat, lng
case locationIsApproximate = "location_is_approximate"
```

### 3. withStatus() Method Update

Updated the immutable copy method to preserve location privacy fields:
```swift
func withStatus(_ newStatus: JobStatus) -> APIJob {
    APIJob(
        // ... existing fields ...
        lat: lat, lng: lng, locationIsApproximate: locationIsApproximate
    )
}
```

---

## UI Implementation

### 1. Map Pin Visualization (`MapHomeView.swift`)

**Updated MapLayerView:**
- Now uses `job.coordinate` computed property instead of the old `approximateCoordinate(for:)` helper
- Passes `isApproximate` parameter to MapPinView

**Enhanced MapPinView:**
- Added `isApproximate: Bool` parameter
- Shows a larger, semi-transparent circle (70-80pt) behind the pin when location is approximate
- Displays a small indicator badge for approximate locations when not selected
- Visual indicator uses 20% opacity of primary/urgent color for the approximate area

```swift
// Approximate location indicator (larger, semi-transparent circle)
if isApproximate {
    Circle()
        .fill((isUrgent ? Theme.Colors.urgent : Theme.Colors.primary).opacity(0.2))
        .frame(width: isSelected ? 80 : 70, height: isSelected ? 80 : 70)
}
```

### 2. Job Card Privacy Indicators

**Updated Cards:**
- `NearbyJobCardView` (MapHomeView.swift)
- `NearbyJobListCard` (ShiftsView.swift)
- `PostedJobListCard` (ShiftsView.swift)
- `CompletedBusinessCard` (ShiftsView.swift)

**Visual Indicator:**
All cards now show a small location circle icon next to the address when `job.locationIsApproximate == true`:

```swift
if let address = job.addressDisplay {
    HStack(spacing: Theme.Spacing.xs) {
        Text(address)
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.secondaryText)
            .lineLimit(1)
        
        // Privacy indicator for approximate locations
        if job.locationIsApproximate == true {
            Image(systemName: "location.circle")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.tertiaryText)
        }
    }
}
```

---

## Backend Integration Notes

### Expected API Behavior

The backend should return these fields in job objects when location blurring is enabled:

```json
{
  "id": 123,
  "title": "Warehouse Worker",
  // ... other fields ...
  "lat": 37.7749,
  "lng": -122.4194,
  "location_is_approximate": true,
  "address_display": "Mission District, San Francisco"
}
```

### Privacy Rules (Backend Implementation)

1. **When to Blur:**
   - Job poster enables privacy setting
   - Before job is filled (protect business location)
   - Based on subscription tier or user preferences

2. **How to Blur:**
   - Offset coordinates by 100-500 meters in random direction
   - Round to fewer decimal places
   - Generalize address (e.g., "Mission District" instead of full street address)

3. **When to Show Precise Location:**
   - Worker has been hired for the job (`status == "filled"`)
   - Job poster viewing their own jobs
   - After worker accepts the position

### API Backward Compatibility

All three new fields are **optional** (`?` in Swift):
- Apps with this update can handle both precise and approximate locations
- Backend can gradually roll out location blurring without breaking existing clients
- If `lat`/`lng` are `nil`, the map pin won't display (maintains existing behavior)
- If `locationIsApproximate` is `nil`, it defaults to `false` (treated as precise)

---

## User Experience

### For Workers:
1. **Map View:** Approximate locations show with a larger, faded circle indicating uncertainty
2. **List Cards:** Small indicator icon next to address shows location is approximate
3. **Distance:** Still accurate (calculated from precise location server-side)
4. **After Hiring:** Receive precise location once accepted

### For Businesses:
1. **Privacy Control:** Can enable location blurring when posting jobs
2. **Visibility:** More applicants due to increased privacy
3. **Security:** Protect business address until worker is hired

---

## Testing Checklist

- [ ] Map pins display correctly for precise locations (`locationIsApproximate == false` or `nil`)
- [ ] Map pins show approximate indicator for blurred locations (`locationIsApproximate == true`)
- [ ] Privacy icon appears on all job cards when location is approximate
- [ ] Distance calculations remain accurate regardless of blurring
- [ ] Backward compatibility: jobs without `lat`/`lng` don't break the UI
- [ ] Map annotation only appears when `job.coordinate` is non-nil
- [ ] All job cards across different views show consistent privacy indicators

---

## Future Enhancements

### Phase 2 (Potential):
1. **Settings UI:** Let businesses toggle location blurring per job
2. **Radius Display:** Show visual radius on map for approximate areas
3. **Tooltip:** Tap info icon to explain why location is approximate
4. **Progressive Disclosure:** Reveal more precise location as application progresses
5. **Subscription Integration:** Premium users can hide exact addresses

### Phase 3 (Advanced):
1. **Geofencing:** Automatic precise location reveal when worker arrives
2. **Privacy Analytics:** Track how blurring affects application rates
3. **Custom Blur Radius:** Let businesses choose 100m, 250m, 500m, etc.

---

## Implementation Status

**Completed:**
- APIJob model with location privacy fields
- CodingKeys for API serialization
- Map pin visual indicators for approximate locations
- Job card privacy badges across all views
- Backward-compatible optional fields
- Documentation

**Pending Backend:**
- API endpoint updates to return `lat`, `lng`, `location_is_approximate`
- Location blurring algorithm (coordinate offsetting)
- Privacy controls in job posting flow
- Conditional precise location reveal on hire

---

## Best Practices Followed

1. **Privacy by Design:** Location blurring is opt-in, clearly indicated
2. **Progressive Disclosure:** Show approximate first, precise later
3. **User Control:** Backend will allow users to control privacy settings
4. **Transparency:** Visual indicators make it clear when location is approximate
5. **Graceful Degradation:** Existing jobs without coordinates continue to work
6. **Performance:** No additional network calls; all data in existing job object
7. **Consistency:** Same privacy indicator across all job card views
8. **Accessibility:** Color and icon used together (not color alone)

---

## Code Quality Notes

- All new properties are properly optional to maintain backward compatibility
- Immutability preserved with updated `withStatus()` method
- Computed property `coordinate` centralizes coordinate logic
- Visual design follows existing Theme constants
- Comments explain the purpose of each privacy-related field
- No breaking changes to existing functionality

---

## System Logic Compliance

**No Contradictions:**
- Distance calculations remain server-side (accurate regardless of display coords)
- Job status flow unchanged (open → filled → completed)
- Application logic unaffected
- Existing nil-checking patterns maintained
- Theme system properly utilized
- SwiftUI best practices followed

---

## Questions for Product Team

1. Should all jobs have blurring by default, or opt-in only?
2. What blur radius should be used (100m, 250m, 500m)?
3. Should we reveal precise location immediately on hire, or after worker confirms?
4. Should business/worker profiles also support location blurring?
5. Any compliance requirements (GDPR, CCPA) for location data?

---

**Last Updated:** March 23, 2026
**Version:** 1.0
**Author:** System Implementation
