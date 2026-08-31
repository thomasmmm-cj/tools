import SwiftUI

struct ContentView: View {
    let store: WaterSampleStore

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
                        store.addSample()
                    } label: {
                        Label("Add Measurement", systemImage: "plus")
                    }
                }
            }
        }
    }
}

private struct MeasurementRow: View {
    let sample: WaterSample

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sample.measuredAt, format: .dateTime)
                .font(.headline)

            HStack(spacing: 16) {
                MeasurementValue(label: "Temp", value: "\(sample.temperatureCelsius, specifier: "%.1f") C")
                MeasurementValue(label: "pH", value: "\(sample.ph)")
                MeasurementValue(label: "O2", value: "\(sample.dissolvedOxygenMilligramsPerLiter, specifier: "%.1f") mg/L")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !sample.notes.isEmpty {
                Text(sample.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
