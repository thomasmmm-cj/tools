import Foundation
import Observation

@Observable
final class WaterSampleStore {
    private(set) var samples: [WaterSample] = []

    func addSample() {
        samples.insert(
            WaterSample(
                id: UUID(),
                lakeName: "Sample Lake",
                measuredAt: Date(),
                latitude: nil,
                longitude: nil,
                temperatureCelsius: 0,
                pH: 7,
                dissolvedOxygenMilligramsPerLiter: 0,
                notes: ""
            ),
            at: 0
        )
    }
}
