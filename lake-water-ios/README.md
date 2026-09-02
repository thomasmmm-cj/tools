# Lake Water

An iOS app for collecting and reviewing water-quality measurements from a lake.

## Features

- SwiftUI iOS app with a measurement list and new-sample form
- Sample metadata: monitor, phone, lake, day, date, and 24-hour time
- Water measurements: temperature at 1 m, 4.5 m, and 9 m, plus Secchi depth
- Secchi bottom visibility and sample-location tracking
- Weather, wind, rain, and wind-direction notes
- Lake-use counts for boats, swimmers, shoreline activity, fishing, and waterfowl
- Algae particle count, color, appearance, bloom size, and sample status
- Latitude, longitude, and non-mid-lake sample-location notes
- Default Pine Lake location from the paper form:
  `47.588744, -122.542320`
- Map chooser for Apple Maps, Google Maps, and Waze when installed

Open `LakeWater/LakeWater.xcodeproj` in Xcode and run the `LakeWater` scheme
on an iPhone simulator. The entry form follows the 2026 Monitoring Data Sheet.

Measurements are currently stored in memory for the active session. Persistence,
export, and backend synchronization have not been added yet.
