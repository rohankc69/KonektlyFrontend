//
//  CountryPickerView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

// MARK: - Country Code Model

enum CountryCode: String, CaseIterable, Identifiable {
    case canada
    case unitedStates
    case unitedKingdom
    case india
    case australia
    case germany
    case france
    case brazil
    case mexico
    case japan
    case southKorea
    case china
    case philippines
    case nigeria
    case southAfrica
    case kenya
    case ghana
    case pakistan
    case bangladesh
    case sriLanka
    case nepal
    case uae
    case saudiArabia
    case newZealand
    case ireland
    case italy
    case spain
    case portugal
    case netherlands
    case sweden
    case norway
    case denmark
    case finland
    case switzerland
    case belgium
    case austria
    case poland
    case turkey
    case egypt
    case colombia
    case argentina
    case chile
    case peru
    case jamaica
    case trinidadAndTobago

    var id: String { rawValue }

    var name: String {
        switch self {
        case .canada: return "Canada"
        case .unitedStates: return "United States"
        case .unitedKingdom: return "United Kingdom"
        case .india: return "India"
        case .australia: return "Australia"
        case .germany: return "Germany"
        case .france: return "France"
        case .brazil: return "Brazil"
        case .mexico: return "Mexico"
        case .japan: return "Japan"
        case .southKorea: return "South Korea"
        case .china: return "China"
        case .philippines: return "Philippines"
        case .nigeria: return "Nigeria"
        case .southAfrica: return "South Africa"
        case .kenya: return "Kenya"
        case .ghana: return "Ghana"
        case .pakistan: return "Pakistan"
        case .bangladesh: return "Bangladesh"
        case .sriLanka: return "Sri Lanka"
        case .nepal: return "Nepal"
        case .uae: return "UAE"
        case .saudiArabia: return "Saudi Arabia"
        case .newZealand: return "New Zealand"
        case .ireland: return "Ireland"
        case .italy: return "Italy"
        case .spain: return "Spain"
        case .portugal: return "Portugal"
        case .netherlands: return "Netherlands"
        case .sweden: return "Sweden"
        case .norway: return "Norway"
        case .denmark: return "Denmark"
        case .finland: return "Finland"
        case .switzerland: return "Switzerland"
        case .belgium: return "Belgium"
        case .austria: return "Austria"
        case .poland: return "Poland"
        case .turkey: return "Turkey"
        case .egypt: return "Egypt"
        case .colombia: return "Colombia"
        case .argentina: return "Argentina"
        case .chile: return "Chile"
        case .peru: return "Peru"
        case .jamaica: return "Jamaica"
        case .trinidadAndTobago: return "Trinidad and Tobago"
        }
    }

    var dialCode: String {
        switch self {
        case .canada: return "+1"
        case .unitedStates: return "+1"
        case .unitedKingdom: return "+44"
        case .india: return "+91"
        case .australia: return "+61"
        case .germany: return "+49"
        case .france: return "+33"
        case .brazil: return "+55"
        case .mexico: return "+52"
        case .japan: return "+81"
        case .southKorea: return "+82"
        case .china: return "+86"
        case .philippines: return "+63"
        case .nigeria: return "+234"
        case .southAfrica: return "+27"
        case .kenya: return "+254"
        case .ghana: return "+233"
        case .pakistan: return "+92"
        case .bangladesh: return "+880"
        case .sriLanka: return "+94"
        case .nepal: return "+977"
        case .uae: return "+971"
        case .saudiArabia: return "+966"
        case .newZealand: return "+64"
        case .ireland: return "+353"
        case .italy: return "+39"
        case .spain: return "+34"
        case .portugal: return "+351"
        case .netherlands: return "+31"
        case .sweden: return "+46"
        case .norway: return "+47"
        case .denmark: return "+45"
        case .finland: return "+358"
        case .switzerland: return "+41"
        case .belgium: return "+32"
        case .austria: return "+43"
        case .poland: return "+48"
        case .turkey: return "+90"
        case .egypt: return "+20"
        case .colombia: return "+57"
        case .argentina: return "+54"
        case .chile: return "+56"
        case .peru: return "+51"
        case .jamaica: return "+1"
        case .trinidadAndTobago: return "+1"
        }
    }

    var flag: String {
        switch self {
        case .canada: return "🇨🇦"
        case .unitedStates: return "🇺🇸"
        case .unitedKingdom: return "🇬🇧"
        case .india: return "🇮🇳"
        case .australia: return "🇦🇺"
        case .germany: return "🇩🇪"
        case .france: return "🇫🇷"
        case .brazil: return "🇧🇷"
        case .mexico: return "🇲🇽"
        case .japan: return "🇯🇵"
        case .southKorea: return "🇰🇷"
        case .china: return "🇨🇳"
        case .philippines: return "🇵🇭"
        case .nigeria: return "🇳🇬"
        case .southAfrica: return "🇿🇦"
        case .kenya: return "🇰🇪"
        case .ghana: return "🇬🇭"
        case .pakistan: return "🇵🇰"
        case .bangladesh: return "🇧🇩"
        case .sriLanka: return "🇱🇰"
        case .nepal: return "🇳🇵"
        case .uae: return "🇦🇪"
        case .saudiArabia: return "🇸🇦"
        case .newZealand: return "🇳🇿"
        case .ireland: return "🇮🇪"
        case .italy: return "🇮🇹"
        case .spain: return "🇪🇸"
        case .portugal: return "🇵🇹"
        case .netherlands: return "🇳🇱"
        case .sweden: return "🇸🇪"
        case .norway: return "🇳🇴"
        case .denmark: return "🇩🇰"
        case .finland: return "🇫🇮"
        case .switzerland: return "🇨🇭"
        case .belgium: return "🇧🇪"
        case .austria: return "🇦🇹"
        case .poland: return "🇵🇱"
        case .turkey: return "🇹🇷"
        case .egypt: return "🇪🇬"
        case .colombia: return "🇨🇴"
        case .argentina: return "🇦🇷"
        case .chile: return "🇨🇱"
        case .peru: return "🇵🇪"
        case .jamaica: return "🇯🇲"
        case .trinidadAndTobago: return "🇹🇹"
        }
    }

    /// Countries ordered with Canada first, then US, then alphabetical
    static var orderedCases: [CountryCode] {
        let prioritized: [CountryCode] = [.canada, .unitedStates]
        let rest = allCases
            .filter { !prioritized.contains($0) }
            .sorted { $0.name < $1.name }
        return prioritized + rest
    }
}

// MARK: - Country Picker View

struct CountryPickerView: View {
    @Binding var selectedCountry: CountryCode
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCode.orderedCases
        }
        let query = searchText.lowercased()
        return CountryCode.orderedCases.filter {
            $0.name.lowercased().contains(query) ||
            $0.dialCode.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCountries) { country in
                    Button {
                        selectedCountry = country
                        dismiss()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Text(country.flag)
                                .font(.system(size: 24))

                            Text(country.name)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)

                            Spacer()

                            Text(country.dialCode)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)

                            if country == selectedCountry {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Colors.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search country or code")
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}

#Preview {
    CountryPickerView(selectedCountry: .constant(.canada))
}
