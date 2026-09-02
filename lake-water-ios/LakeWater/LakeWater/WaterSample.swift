import Foundation

enum DefaultSampleLocation {
    static let lakeName = "Pine Lake"
    static let latitude = 47.588744
    static let longitude = -122.542320
}

enum SamplingDay: String, CaseIterable, Identifiable, Codable {
    case sunday = "Sunday"
    case monday = "Monday"

    var id: String { rawValue }
}

enum WeatherCondition: String, CaseIterable, Identifiable, Codable {
    case sunny = "Sunny"
    case partlyCloudy = "Partly cloudy"
    case cloudy = "Cloudy"
    case raining = "Raining"

    var id: String { rawValue }
}

enum WindCondition: String, CaseIterable, Identifiable, Codable {
    case noWind = "No wind"
    case slightWind = "Slight wind"
    case breezy = "Breezy"
    case stormy = "Stormy"

    var id: String { rawValue }
}

enum CountRange: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case oneToTen = "1-10"
    case elevenToFifty = "11-50"
    case fiftyOneToOneHundred = "51-100"
    case moreThanOneHundred = ">100"

    var id: String { rawValue }
}

enum AlgaeParticleCount: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case oneToFifty = "1-50 particles"
    case fiftyOneToOneHundred = "51-100 particles"
    case moreThanOneHundred = ">100 particles"

    var id: String { rawValue }
}

enum AlgaeColor: String, CaseIterable, Identifiable, Codable {
    case blue = "Blue"
    case green = "Green"
    case greenishBlue = "Greenish-blue"
    case other = "Other"

    var id: String { rawValue }
}

enum AlgaeAppearance: String, CaseIterable, Identifiable, Codable {
    case flecks = "Flecks"
    case smallClumps = "Small clumps"
    case thinFilm = "Thin film"
    case thickScum = "Thick scum"
    case other = "Other"

    var id: String { rawValue }
}

enum BloomSize: String, CaseIterable, Identifiable, Codable {
    case smallPatchyAreas = "Small patchy areas"
    case car = "About the size of a car"
    case tennisCourt = "About the size of a tennis court"
    case largerArea = "Larger area"

    var id: String { rawValue }
}

struct WaterSample: Identifiable, Codable, Hashable {
    let id: UUID
    var volunteerMonitor: String
    var phone: String
    var lakeName: String
    var samplingDay: SamplingDay
    var sampleDate: Date
    var sampleTime: Date
    var temperatureAtOneMeterCelsius: Double?
    var temperatureAtFourPointFiveMetersCelsius: Double?
    var temperatureAtNineMetersCelsius: Double?
    var secchiDepthMeters: Double?
    var discVisibleOnBottom: Bool?
    var lakeBottomDepthMeters: Double?
    var secchiReadingAtSampleLocation: Bool?
    var secchiOtherLocation: String
    var weather: WeatherCondition?
    var wind: WindCondition?
    var windDirectionNote: String
    var rainLast24HoursMillimeters: Double?
    var boats: CountRange?
    var swimmers: CountRange?
    var shorelinePeople: CountRange?
    var fishingPeople: CountRange?
    var waterfowlCount: Int?
    var algaeParticleCount: AlgaeParticleCount?
    var filamentousAlgaeObserved: Bool?
    var algaeScumObserved: Bool?
    var algaeColor: AlgaeColor?
    var algaeOtherColor: String
    var algaeAppearance: AlgaeAppearance?
    var algaeOtherAppearance: String
    var algaeBloomSize: BloomSize?
    var algaeSampleProvided: Bool?
    var latitude: Double?
    var longitude: Double?
    var sampleLocationNote: String
    var notes: String
}
