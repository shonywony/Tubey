import SwiftUI

@main
struct TubeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browser = BrowserModel()

    var body: some Scene {
        Window("Tubey", id: "main") {
            ContentView()
                .environmentObject(browser)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            // Single-window app: hide "New Window".
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Navigate") {
                Button("Back") { browser.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!browser.canGoBack)

                Button("Forward") { browser.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!browser.canGoForward)

                Divider()

                Button("Reload") { browser.reload() }
                    .keyboardShortcut("r", modifiers: .command)

                Button("Home") { browser.goHome() }
                    .keyboardShortcut("h", modifiers: [.command, .shift])

                Divider()

                Button("Sign In with Google…") { browser.signIn() }
            }

            CommandGroup(after: .toolbar) {
                Toggle("Show Bandwidth Monitor", isOn: $browser.showBandwidth)
                Toggle("Hide Shorts", isOn: $browser.hideShorts)
                Toggle("Focus Mode", isOn: $browser.focusMode)
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandMenu("Privacy") {
                Toggle("Block Watch-Time Tracking (turns off watch history)", isOn: $browser.blockWatchHistory)
            }

            CommandMenu("Video") {
                Button("Picture in Picture") { browser.togglePictureInPicture() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Toggle("Skip Sponsors (SponsorBlock)", isOn: $browser.skipSponsors)
                Toggle("Also Skip Intros & Outros", isOn: $browser.skipIntrosAndOutros)
                    .disabled(!browser.skipSponsors)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Always use dark mode, whatever your Mac is set to.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    // Quit when the window closes, so audio doesn't keep playing in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
