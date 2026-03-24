//
//  JobLocationView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import MapKit

/// Example component showing how to gate exact job location with Konektly+
/// Use this pattern in your job detail/card views
struct JobLocationView: View {
    let locationIsApproximate: Bool
    let addressDisplay: String?
    let latitude: Double
    let longitude: Double
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSubscriptionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Address display
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: locationIsApproximate ? "mappin.circle" : "mappin.circle.fill")
                    .foregroundStyle(locationIsApproximate ? Theme.Colors.secondaryText : Theme.Colors.accent)
                
                if subscriptionManager.isKonektlyPlus {
                    // Konektly+ user: show exact address
                    Text(addressDisplay ?? "Address not available")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.primaryText)
                } else {
                    // Free user: show approximate location
                    if locationIsApproximate {
                        Text("Approximate location")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        Text(addressDisplay ?? "")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                }
            }
            
            // Map preview
            Map(position: .constant(.region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            ))) {
                Marker("Job Location", coordinate: CLLocationCoordinate2D(
                    latitude: latitude,
                    longitude: longitude
                ))
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .allowsHitTesting(false)
            
            // Upgrade CTA for free users with approximate locations
            if !subscriptionManager.isKonektlyPlus && locationIsApproximate {
                Button {
                    showSubscriptionSheet = true
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Unlock exact location with Konektly+")
                    }
                }
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Sizes.smallButtonHeight)
                .background(Theme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            NavigationStack {
                SubscriptionView()
                    .navigationTitle("Konektly+")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showSubscriptionSheet = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview("Free User - Approximate") {
    JobLocationView(
        locationIsApproximate: true,
        addressDisplay: nil,
        latitude: 43.6532,
        longitude: -79.3832
    )
    .padding()
}

#Preview("Plus User - Exact") {
    JobLocationView(
        locationIsApproximate: false,
        addressDisplay: "123 King Street West, Toronto, ON",
        latitude: 43.6532,
        longitude: -79.3832
    )
    .padding()
}
