//
//  PostJobView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-07.
//

import SwiftUI
import CoreLocation

struct PostJobView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var jobStore: JobStore
    @EnvironmentObject private var locationManager: LocationManager

    // MARK: Form Fields
    @State private var title = ""
    @State private var description = ""
    @State private var payRate = ""
    @State private var scheduledStart = Date().addingTimeInterval(3600)
    @State private var scheduledEnd   = Date().addingTimeInterval(7200)
    @State private var hasEndTime     = true
    @State private var address        = ""

    @State private var resolvedLat: Double? = nil
    @State private var resolvedLng: Double? = nil
    @State private var locationSource: LocationSource = .none

    @State private var isSubmitting   = false
    @State private var errorMessage: String?
    @State private var fieldErrors: [String: String] = [:]
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, description, payRate, address }
    private enum LocationSource    { case none, gps, manual }

    // MARK: - Computed

    private var isFormValid: Bool {
        !isSubmitting &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Decimal(string: payRate.trimmingCharacters(in: .whitespaces)) ?? 0) > 0 &&
        (locationSource != .none || !address.trimmingCharacters(in: .whitespaces).isEmpty) &&
        (!hasEndTime || scheduledEnd > scheduledStart)
    }

    private var estimatedEarnings: String? {
        guard hasEndTime,
              let rate = Double(payRate.trimmingCharacters(in: .whitespaces)),
              rate > 0 else { return nil }
        let hours = max(0, scheduledEnd.timeIntervalSince(scheduledStart) / 3600)
        guard hours > 0 else { return nil }
        return String(format: "%.1f hrs · $%.2f est.", hours, hours * rate)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {

                    // Header — matches NameEntryView / ProfileCreateView exactly
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Post a job")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Fill in the details and workers near you will see it")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // MARK: Job Details
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                        // Title
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Job title")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)

                            TextField("e.g. Event Server, Bartender", text: $title)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .focused($focusedField, equals: .title)
                                .autocorrectionDisabled()
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(
                                            focusedField == .title
                                                ? Theme.Colors.inputBorderFocused
                                                : fieldErrors["title"] != nil ? Theme.Colors.error : Color.clear,
                                            lineWidth: 2
                                        )
                                )

                            if let err = fieldErrors["title"] {
                                Text(err)
                                    .font(Theme.Typography.footnote)
                                    .foregroundColor(Theme.Colors.error)
                            }
                        }

                        // Description
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack(spacing: Theme.Spacing.sm) {
                                Text("Description")
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Text("Optional")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }

                            TextField(
                                "Uniform, duties, what to bring…",
                                text: $description,
                                axis: .vertical
                            )
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                            .focused($focusedField, equals: .description)
                            .lineLimit(3...6)
                            .padding(Theme.Spacing.lg)
                            .background(Theme.Colors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .stroke(
                                        focusedField == .description
                                            ? Theme.Colors.inputBorderFocused : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                    }

                    // MARK: Pay Rate
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Hourly rate (CAD)")
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.primaryText)

                        HStack(spacing: Theme.Spacing.xs) {
                            Text("$")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)

                            TextField("18.50", text: $payRate)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .payRate)
                                .onChange(of: payRate) { _, v in
                                    let filtered = v.filter { $0.isNumber || $0 == "." }
                                    if filtered != v { payRate = filtered }
                                }

                            Text("/ hr")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                        .padding(Theme.Spacing.lg)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(
                                    focusedField == .payRate
                                        ? Theme.Colors.inputBorderFocused
                                        : fieldErrors["payRate"] != nil ? Theme.Colors.error : Color.clear,
                                    lineWidth: 2
                                )
                        )

                        if let err = fieldErrors["payRate"] {
                            Text(err)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.error)
                        }
                    }

                    // MARK: Schedule
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                        // Shift start
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Shift start")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)

                            DatePicker("", selection: $scheduledStart,
                                       in: Date()...,
                                       displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Theme.Colors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .onChange(of: scheduledStart) { _, newStart in
                                    if scheduledEnd <= newStart {
                                        scheduledEnd = newStart.addingTimeInterval(1800)
                                    }
                                }
                        }

                        // Shift end — optional toggle
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Toggle(isOn: $hasEndTime.animation()) {
                                Text("Shift end")
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            .tint(Theme.Colors.accent)

                            if hasEndTime {
                                DatePicker("", selection: $scheduledEnd,
                                           in: scheduledStart.addingTimeInterval(60)...,
                                           displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(Theme.Colors.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Theme.Spacing.lg)
                                    .background(Theme.Colors.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))

                                if let err = fieldErrors["scheduledEnd"] {
                                    Text(err)
                                        .font(Theme.Typography.footnote)
                                        .foregroundColor(Theme.Colors.error)
                                }
                            }
                        }

                        // Duration / earnings preview
                        if let preview = estimatedEarnings {
                            Text(preview)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }

                    // MARK: Location
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                        Text("Location")
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.primaryText)

                        // GPS row — same style as the globe/phone row in PhoneLoginView
                        Button(action: resolveGPS) {
                            HStack {
                                Image(systemName: locationSource == .gps
                                      ? "location.fill" : "location")
                                    .font(.system(size: 18))
                                    .foregroundColor(
                                        locationSource == .gps
                                            ? Theme.Colors.accent
                                            : Theme.Colors.secondaryText
                                    )
                                Text(gpsButtonLabel)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(
                                        locationSource == .gps
                                            ? Theme.Colors.primaryText
                                            : Theme.Colors.secondaryText
                                    )
                                Spacer()
                                if locationManager.isLocating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if locationSource == .gps {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .padding(Theme.Spacing.lg)
                            .background(Theme.Colors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                        }
                        .buttonStyle(.plain)
                        .disabled(locationManager.isLocating ||
                                  locationManager.authStatus == .denied)

                        // "or" divider
                        HStack {
                            Rectangle().fill(Theme.Colors.divider).frame(height: 1)
                            Text("or")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .fixedSize()
                            Rectangle().fill(Theme.Colors.divider).frame(height: 1)
                        }

                        // Address field
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            TextField("123 Main St, Winnipeg, MB",
                                      text: $address, axis: .vertical)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .focused($focusedField, equals: .address)
                                .lineLimit(2...3)
                                .autocorrectionDisabled()
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(
                                            focusedField == .address
                                                ? Theme.Colors.inputBorderFocused
                                                : fieldErrors["location"] != nil ? Theme.Colors.error : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .onChange(of: address) { _, v in
                                    if !v.isEmpty {
                                        locationSource = .manual
                                        resolvedLat = nil; resolvedLng = nil
                                    } else if resolvedLat == nil {
                                        locationSource = .none
                                    }
                                }

                            if let err = fieldErrors["location"] {
                                Text(err)
                                    .font(Theme.Typography.footnote)
                                    .foregroundColor(Theme.Colors.error)
                            }
                        }

                        if locationManager.authStatus == .denied {
                            Text("Enable Location in Settings to use GPS.")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }

                    // API error — same plain footnote style as every other screen
                    if let err = errorMessage {
                        Text(err)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)

            // MARK: Bottom bar — identical pattern to OnboardingBottomBar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(Circle())
                }

                Spacer()

                Button(action: submit) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(width: 120, height: 48)
                    } else {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("Post job")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .frame(height: 48)
                    }
                }
                .background(isFormValid ? Color.black : Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
                .disabled(!isFormValid)
                .animation(.easeInOut(duration: 0.15), value: isFormValid)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        // Success toast
        .overlay(alignment: .top) {
            if showSuccessBanner {
                Text("Job posted!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .padding(.top, Theme.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuccessBanner)
    }

    // MARK: - State (keep alongside body for clarity)
    @State private var showSuccessBanner = false

    // MARK: - Actions

    private func resolveGPS() {
        Task {
            locationManager.requestAuthorization()
            guard let coord = await locationManager.currentCoordinate() else { return }
            resolvedLat    = coord.latitude
            resolvedLng    = coord.longitude
            locationSource = .gps
            address        = ""
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting  = true
        fieldErrors   = [:]
        errorMessage  = nil
        focusedField  = nil

        let trimTitle   = title.trimmingCharacters(in: .whitespaces)
        let trimPay     = payRate.trimmingCharacters(in: .whitespaces)
        let trimAddress = address.trimmingCharacters(in: .whitespaces)

        if trimTitle.isEmpty {
            fieldErrors["title"] = "Job title is required."
        }
        guard let payDecimal = Decimal(string: trimPay), payDecimal > 0 else {
            fieldErrors["payRate"] = "Enter a valid rate greater than $0."
            isSubmitting = false; return
        }
        if hasEndTime && scheduledEnd <= scheduledStart {
            fieldErrors["scheduledEnd"] = "End time must be after start time."
            isSubmitting = false; return
        }
        if resolvedLat == nil && trimAddress.isEmpty {
            fieldErrors["location"] = "Add a location via GPS or enter an address."
            isSubmitting = false; return
        }
        if !fieldErrors.isEmpty { isSubmitting = false; return }

        Task {
            // If GPS coordinates are available, reverse-geocode to get a human-readable
            // address string. This prevents address_display showing raw coordinates
            // like "49.895100, -97.138400" everywhere in the app.
            var resolvedAddress: String? = trimAddress.isEmpty ? nil : trimAddress
            if let lat = resolvedLat, let lng = resolvedLng, resolvedAddress == nil {
                let geocoder = CLGeocoder()
                let location = CLLocation(latitude: lat, longitude: lng)
                if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
                   let place = placemarks.first {
                    let parts: [String?] = [
                        place.subThoroughfare,   // street number
                        place.thoroughfare,       // street name
                        place.locality,           // city
                        place.administrativeArea  // province/state
                    ]
                    resolvedAddress = parts.compactMap { $0 }.joined(separator: ", ")
                }
            }

            let result = await jobStore.postJob(
                title: trimTitle,
                description: description.trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil : description.trimmingCharacters(in: .whitespaces),
                payRate: trimPay,
                scheduledStart: scheduledStart,
                scheduledEnd: hasEndTime ? scheduledEnd : nil,
                lat: resolvedLat,
                lng: resolvedLng,
                address: resolvedAddress
            )
            if result != nil {
                withAnimation { showSuccessBanner = true }
                try? await Task.sleep(for: .seconds(1.2))
                dismiss()
            } else {
                errorMessage = jobStore.postJobError?.errorDescription
                    ?? "Failed to post job. Please try again."
                isSubmitting = false
            }
        }
    }

    private var gpsButtonLabel: String {
        if locationManager.isLocating         { return "Getting location…" }
        if locationSource == .gps             { return "Using current location" }
        if locationManager.authStatus == .denied { return "Location access disabled" }
        return "Use my current location"
    }
}

#Preview {
    PostJobView()
        .environmentObject(JobStore.shared)
        .environmentObject(LocationManager())
}
