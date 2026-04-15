import SwiftUI

@main
struct AltTabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup("AltTab Windows") {
            ContentView()
                .environmentObject(controller)
                .frame(width: 520, height: 360)
                .onAppear {
                    appDelegate.controller = controller
                    controller.start()
                }
        }
        .defaultSize(width: 520, height: 360)
        .windowResizability(.contentSize)
    }
}
