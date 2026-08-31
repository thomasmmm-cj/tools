import SwiftUI

@main
struct LakeWaterApp: App {
    @State private var store = WaterSampleStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
