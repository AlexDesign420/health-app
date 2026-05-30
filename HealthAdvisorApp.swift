import SwiftUI

@main
struct HealthAdvisorApp: App {
    @StateObject private var healthManager = HealthManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
        }
    }
}
