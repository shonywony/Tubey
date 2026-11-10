import SwiftUI

extension Color {
    /// The red from the Tubey app icon.
    static let tubeyRed = Color(red: 0.6, green: 0, blue: 0)
}

struct ContentView: View {
    @EnvironmentObject private var browser: BrowserModel

    var body: some View {
        WebView(webView: browser.webView)
            .frame(minWidth: 400, minHeight: 300)
            .overlay(alignment: .bottomTrailing) {
                if browser.showBandwidth {
                    BandwidthBadge(monitor: browser.bandwidth, tint: .tubeyRed)
                        .padding(12)
                }
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Tubey")
            // The toolbar shows the logo + name instead of the plain title text.
            // (The window keeps its title for Mission Control, the Window menu and VoiceOver.)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { browser.goBack() } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(!browser.canGoBack)
                    .help("Back (⌘[)")

                    Button { browser.goForward() } label: {
                        Label("Forward", systemImage: "chevron.right")
                    }
                    .disabled(!browser.canGoForward)
                    .help("Forward (⌘])")

                    Button { browser.goHome() } label: {
                        Label("Home", systemImage: "house")
                    }
                    .help("Home (⇧⌘H)")
                }

                // Keep the logo out of the buttons' glass bubble.
                ToolbarSpacer(.fixed, placement: .navigation)

                // Logo + name in place of the plain window title.
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 7) {
                        Image("TitleLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 18)
                        Text("Tubey")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tubey")
                }
                .sharedBackgroundVisibility(.hidden)

                // Push Reload and Picture in Picture back to the right-hand side.
                ToolbarSpacer(.flexible)

                ToolbarItemGroup(placement: .primaryAction) {
                    if browser.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button { browser.reload() } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .help("Reload (⌘R)")

                    Button { browser.togglePictureInPicture() } label: {
                        Label("Picture in Picture", systemImage: "pip.enter")
                    }
                    .help("Picture in Picture (⇧⌘P)")
                }
            }
            // Paint the title/toolbar bar the same red as the app icon.
            // Newer macOS uses a see-through glass bar, so the red also goes behind it;
            // older macOS uses the toolbar background setting.
            .background(Color.tubeyRed.ignoresSafeArea())
            .toolbarBackground(Color.tubeyRed, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }
}

