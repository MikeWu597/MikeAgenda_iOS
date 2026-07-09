import SwiftUI

@main
struct MikeAgendaApp: App {
    @StateObject private var sessionService = SessionService.shared
    @StateObject private var settingsService = SettingsService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionService)
                .environmentObject(settingsService)
                .preferredColorScheme(settingsService.effectiveColorScheme)
        }
    }
}
