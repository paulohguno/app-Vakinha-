import SwiftUI

@main
struct aulamoretoApp: App {
    @StateObject private var vm = AppViewModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
        }
    }
}
