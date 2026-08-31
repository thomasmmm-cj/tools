import Foundation

struct WaterSample: Identifiable, Codable, Hashable {
    let id: UUID
    let lakeName: String
    let measuredAt: Date
    let latitude: Double?
    let longitude: Double?
    let temperatureCelsius: Double
    let pH: Double
    let dissolvedOxygenMilligramsPerLiter: Double
    let notes: String
}
