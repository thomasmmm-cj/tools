import Foundation
import MapKit
import SwiftUI
import UIKit

struct ContentView: View {
    let store: WaterSampleStore
    @State private var showingEntryForm = false

    var body: some View {
        NavigationStack {
            Group {
                if store.samples.isEmpty {
                    ContentUnavailableView(
                        "No Measurements",
                        systemImage: "drop",
                        description: Text("Add your first lake-water measurement.")
                    )
                } else {
                    List(store.samples) { sample in
                        MeasurementRow(sample: sample)
                    }
                }
            }
            .navigationTitle("Lake Water")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEntryForm = true
                    } label: {
                        Label("Add Measurement", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEntryForm) {
                SampleEntryView { sample in
                    store.add(sample)
                    showingEntryForm = false
                }
            }
        }
    }
}

private struct MeasurementRow: View {
    let sample: WaterSample

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sample.lakeName.isEmpty ? "Unnamed lake" : sample.lakeName)
                .font(.headline)
            Text(sample.sampleDate, format: .dateTime.month().day().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                MeasurementValue(label: "Surface", value: formatted(sample.temperatureAtOneMeterCelsius, suffix: " C"))
                MeasurementValue(label: "Secchi", value: formatted(sample.secchiDepthMeters, suffix: " m"))
                MeasurementValue(label: "Algae", value: sample.algaeParticleCount?.rawValue ?? "-")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f%@", value, suffix)
    }
}

private struct MeasurementValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
            Text(value)
        }
    }
}

private struct SampleEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (WaterSample) -> Void
    @State private var showingMapOptions = false

    @State private var volunteerMonitor = ""
    @State private var phone = ""
    @State private var lakeName = DefaultSampleLocation.lakeName
    @State private var samplingDay = SamplingDay.sunday
    @State private var sampleDate = Date()
    @State private var sampleTime = Date()
    @State private var surfaceTemperature = ""
    @State private var midDepthTemperature = ""
    @State private var nearBottomTemperature = ""
    @State private var secchiDepth = ""
    @State private var discVisibleOnBottom = false
    @State private var lakeBottomDepth = ""
    @State private var secchiReadingLocation = "Yes"
    @State private var secchiOtherLocation = ""
    @State private var weather = WeatherCondition.sunny
    @State private var wind = WindCondition.noWind
    @State private var windDirectionNote = ""
    @State private var rainLast24Hours = ""
    @State private var boats = CountRange.none
    @State private var swimmers = CountRange.none
    @State private var shorelinePeople = CountRange.none
    @State private var fishingPeople = CountRange.none
    @State private var waterfowlCount = ""
    @State private var algaeParticleCount = AlgaeParticleCount.none
    @State private var filamentousAlgae = false
    @State private var algaeScum = false
    @State private var algaeColor = AlgaeColor.blue
    @State private var algaeOtherColor = ""
    @State private var algaeAppearance = AlgaeAppearance.flecks
    @State private var algaeOtherAppearance = ""
    @State private var bloomSize = BloomSize.smallPatchyAreas
    @State private var algaeSampleProvided = false
    @State private var latitude = String(format: "%.6f", DefaultSampleLocation.latitude)
    @State private var longitude = String(format: "%.6f", DefaultSampleLocation.longitude)
    @State private var sampleLocationNote = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sample information") {
                    TextField("Volunteer monitor", text: $volunteerMonitor)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Lake", text: $lakeName)

                    Picker("Day", selection: $samplingDay) {
                        ForEach(SamplingDay.allCases) { day in
                            Text(day.rawValue).tag(day)
                        }
                    }
                    DatePicker("Date", selection: $sampleDate, displayedComponents: .date)
                    DatePicker("24-hour time", selection: $sampleTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    DecimalField("At one meter", value: $surfaceTemperature, unit: "C")
                    DecimalField("At 4.5 m depth", value: $midDepthTemperature, unit: "C")
                    DecimalField("At 9 m depth", value: $nearBottomTemperature, unit: "C")
                } header: {
                    Text("Temperature")
                } footer: {
                    Text("Measure at all depths for every event. Record to the nearest 0.5 C.")
                }

                Section("Secchi depth") {
                    DecimalField("Secchi depth", value: $secchiDepth, unit: "m")
                    Toggle("Disc visible on lake bottom", isOn: $discVisibleOnBottom)
                    if discVisibleOnBottom {
                        DecimalField("Lake bottom depth", value: $lakeBottomDepth, unit: "m")
                    }
                    Picker("Reading at sample location", selection: $secchiReadingLocation) {
                        Text("Yes").tag("Yes")
                        Text("No").tag("No")
                        Text("Other").tag("Other")
                    }
                    if secchiReadingLocation == "Other" {
                        TextField("Other location", text: $secchiOtherLocation)
                    }
                }

                Section("Weather") {
                    Picker("Conditions", selection: $weather) {
                        ForEach(WeatherCondition.allCases) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                    Picker("Wind", selection: $wind) {
                        ForEach(WindCondition.allCases) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                    DecimalField("Rain last 24 hours", value: $rainLast24Hours, unit: "mm")
                    TextField("Wind direction / map note", text: $windDirectionNote, axis: .vertical)
                }

                Section("Lake use") {
                    CountPicker("Boats on lake", selection: $boats)
                    CountPicker("Swimmers in lake", selection: $swimmers)
                    CountPicker("People on shoreline", selection: $shorelinePeople)
                    CountPicker("People fishing", selection: $fishingPeople)
                    TextField("Waterfowl count (total)", text: $waterfowlCount)
                        .keyboardType(.numberPad)
                }

                Section("Algae particle count") {
                    Picker("Particles on Secchi disk", selection: $algaeParticleCount) {
                        ForEach(AlgaeParticleCount.allCases) { count in
                            Text(count.rawValue).tag(count)
                        }
                    }
                }

                Section("Algae observed") {
                    Toggle("Filamentous algae observed", isOn: $filamentousAlgae)
                    Toggle("Algae scum observed", isOn: $algaeScum)
                    Picker("Algae color", selection: $algaeColor) {
                        ForEach(AlgaeColor.allCases) { color in
                            Text(color.rawValue).tag(color)
                        }
                    }
                    if algaeColor == .other {
                        TextField("Other color", text: $algaeOtherColor)
                    }
                    Picker("Algae appearance", selection: $algaeAppearance) {
                        ForEach(AlgaeAppearance.allCases) { appearance in
                            Text(appearance.rawValue).tag(appearance)
                        }
                    }
                    if algaeAppearance == .other {
                        TextField("Other appearance", text: $algaeOtherAppearance)
                    }
                    Picker("Bloom size", selection: $bloomSize) {
                        ForEach(BloomSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    Toggle("Algae sample provided", isOn: $algaeSampleProvided)
                }

                Section("Sample location and notes") {
                    DecimalField("Latitude", value: $latitude)
                    DecimalField("Longitude", value: $longitude)
                    if validCoordinate != nil {
                        Button {
                            showingMapOptions = true
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                        }
                    }
                    TextField("Non-mid-lake sample location", text: $sampleLocationNote, axis: .vertical)
                    TextField("Other information", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("New Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Open location in",
                isPresented: $showingMapOptions,
                titleVisibility: .visible
            ) {
                Button("Apple Maps") {
                    openAppleMaps()
                }
                if googleMapsIsInstalled {
                    Button("Google Maps") {
                        openGoogleMaps()
                    }
                }
                if wazeIsInstalled {
                    Button("Waze") {
                        openWaze()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(lakeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let sample = WaterSample(
            id: UUID(),
            volunteerMonitor: volunteerMonitor,
            phone: phone,
            lakeName: lakeName,
            samplingDay: samplingDay,
            sampleDate: sampleDate,
            sampleTime: sampleTime,
            temperatureAtOneMeterCelsius: Double(surfaceTemperature),
            temperatureAtFourPointFiveMetersCelsius: Double(midDepthTemperature),
            temperatureAtNineMetersCelsius: Double(nearBottomTemperature),
            secchiDepthMeters: Double(secchiDepth),
            discVisibleOnBottom: discVisibleOnBottom,
            lakeBottomDepthMeters: Double(lakeBottomDepth),
            secchiReadingAtSampleLocation: secchiReadingLocation == "Yes" ? true : secchiReadingLocation == "No" ? false : nil,
            secchiOtherLocation: secchiOtherLocation,
            weather: weather,
            wind: wind,
            windDirectionNote: windDirectionNote,
            rainLast24HoursMillimeters: Double(rainLast24Hours),
            boats: boats,
            swimmers: swimmers,
            shorelinePeople: shorelinePeople,
            fishingPeople: fishingPeople,
            waterfowlCount: Int(waterfowlCount),
            algaeParticleCount: algaeParticleCount,
            filamentousAlgaeObserved: filamentousAlgae,
            algaeScumObserved: algaeScum,
            algaeColor: algaeColor,
            algaeOtherColor: algaeOtherColor,
            algaeAppearance: algaeAppearance,
            algaeOtherAppearance: algaeOtherAppearance,
            algaeBloomSize: bloomSize,
            algaeSampleProvided: algaeSampleProvided,
            latitude: Double(latitude),
            longitude: Double(longitude),
            sampleLocationNote: sampleLocationNote,
            notes: notes
        )
        onSave(sample)
    }

    private var validCoordinate: CLLocationCoordinate2D? {
        guard let latitude = Double(latitude), let longitude = Double(longitude),
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var googleMapsIsInstalled: Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private var wazeIsInstalled: Bool {
        guard let url = URL(string: "waze://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func openAppleMaps() {
        guard let coordinate = validCoordinate else { return }
        let item = MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
        item.name = lakeName.isEmpty ? "Water sample location" : lakeName
        item.openInMaps()
    }

    private func openGoogleMaps() {
        guard let coordinate = validCoordinate,
              let url = URL(string: "comgooglemaps://?center=\(coordinate.latitude),\(coordinate.longitude)&zoom=14&q=\(coordinate.latitude),\(coordinate.longitude)") else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func openWaze() {
        guard let coordinate = validCoordinate,
              let url = URL(string: "waze://?ll=\(coordinate.latitude),\(coordinate.longitude)&navigate=no") else {
            return
        }
        UIApplication.shared.open(url)
    }
}

private struct DecimalField: View {
    let title: String
    @Binding var value: String
    var unit: String?

    init(_ title: String, value: Binding<String>, unit: String? = nil) {
        self.title = title
        self._value = value
        self.unit = unit
    }

    var body: some View {
        HStack {
            TextField(title, text: $value)
                .keyboardType(.decimalPad)
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CountPicker: View {
    let title: String
    @Binding var selection: CountRange

    init(_ title: String, selection: Binding<CountRange>) {
        self.title = title
        self._selection = selection
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(CountRange.allCases) { count in
                Text(count.rawValue).tag(count)
            }
        }
    }
}
