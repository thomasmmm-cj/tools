import Foundation
import Observation

@Observable
final class WaterSampleStore {
    private(set) var samples: [WaterSample] = []

    func add(_ sample: WaterSample) {
        samples.insert(sample, at: 0)
    }
}
