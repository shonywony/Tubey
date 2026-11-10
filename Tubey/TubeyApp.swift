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
            HelpCommands()

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

            CommandMenu("Video") {
                Button("Picture in Picture") { browser.togglePictureInPicture() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            // Everything you can switch on and off lives in the toolbar's Features and Add-ons menus.
        }

        // Explains every feature. Help → Tubey Help (⌘?).
        Window("Tubey Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 860, height: 620)

        // The mini player in the menu bar (Add-ons → Menu Bar Player turns it off).
        // Only pass real changes back: SwiftUI re-sends the current value while it draws, and saving
        // that would redraw the app again and again.
        MenuBarExtra(isInserted: Binding(
            get: { browser.showMenuBarPlayer },
            set: { if browser.showMenuBarPlayer != $0 { browser.showMenuBarPlayer = $0 } }
        )) {
            MiniPlayerView(nowPlaying: browser.nowPlaying)
                .environmentObject(browser)
        } label: {
            MenuBarIcon(nowPlaying: browser.nowPlaying)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Replaces the standard Help menu item with Tubey's own Help window.
struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Tubey Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Use the saved appearance (Dark unless you've picked Light or Match System).
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = AppAppearance.saved.nsAppearance
    }

    // Quit when the window closes, so audio doesn't keep playing in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
