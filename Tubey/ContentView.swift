import SwiftUI

extension Color {
    /// The red from the Tubey app icon.
    static let tubeyRed = Color(red: 0.6, green: 0, blue: 0)
}

struct ContentView: View {
    @EnvironmentObject private var browser: BrowserModel
    @State private var featuresAnchor = MenuAnchorBox()
    @State private var addOnsAnchor = MenuAnchorBox()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WebView(webView: browser.webView)
            .frame(minWidth: 400, minHeight: 300)
            .overlay(alignment: .bottomTrailing) {
                if browser.showBandwidth {
                    BandwidthBadge(monitor: browser.bandwidth, tint: .tubeyRed)
                        .padding(12)
                }
            }
            .background(browser.appearance == .light ? Color.white : Color.black)
            // ⇧⌘F turns Hide Recommendations on and off (the switch itself is in the Features menu).
            .background {
                Button("Hide Recommendations") { browser.hideRecommendations.toggle() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .opacity(0)
                    .accessibilityHidden(true)
            }
            .preferredColorScheme(browser.appearance.colorScheme)
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
                    // While a page loads, the spinner takes the reload arrow's place in a fixed-size slot,
                    // so the toolbar doesn't resize (which was clipping the spinner).
                    Button { browser.reload() } label: {
                        Label {
                            Text("Reload")
                        } icon: {
                            ZStack {
                                if browser.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .frame(width: 18, height: 18)
                        }
                    }
                    .help("Reload (⌘R)")

                    PictureInPictureButton(nowPlaying: browser.nowPlaying) { browser.togglePictureInPicture() }

                    // Light/dark switch: the moon means Tubey is dark, the sun means it's light.
                    Button {
                        browser.appearance = colorScheme == .dark ? .light : .dark
                    } label: {
                        Label("Appearance", systemImage: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                    }
                    .help(colorScheme == .dark ? "Switch to Light" : "Switch to Dark")

                    // Tubey's extras: dislikes, DeArrow, menu bar player, bandwidth and privacy.
                    Button {
                        SpecialFeaturesMenu.showAddOns(for: browser, from: addOnsAnchor.view)
                    } label: {
                        Label("Add-ons", systemImage: "puzzlepiece.extension")
                            .labelStyle(.titleAndIcon)
                    }
                    .background(MenuAnchor(box: addOnsAnchor))
                    .help("Add-ons")

                    // Tubey's browsing, clean view and playback features in one native menu.
                    Button {
                        SpecialFeaturesMenu.show(for: browser, from: featuresAnchor.view)
                    } label: {
                        Label("Features", systemImage: "slider.horizontal.3")
                            .labelStyle(.titleAndIcon)
                    }
                    .background(MenuAnchor(box: featuresAnchor))
                    .help("Features")

                    Button { openWindow(id: "help") } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    .help("Tubey Help (⌘?)")
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

/// The toolbar's Picture in Picture button: only clickable while a video is open (playing or paused).
struct PictureInPictureButton: View {
    @ObservedObject var nowPlaying: NowPlaying
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Picture in Picture", systemImage: "pip.enter")
        }
        .disabled(!nowPlaying.hasVideo)
        .help(nowPlaying.hasVideo ? "Picture in Picture (⇧⌘P)" : "Picture in Picture (start a video first)")
    }
}
