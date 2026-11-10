import AppKit
import SwiftUI
import WebKit

/// Dark, Light, or follow the Mac's own setting.
enum AppAppearance: String, CaseIterable, Identifiable {
    case dark, light, system
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "Match System"
        }
    }

    /// The saved choice (Dark until you pick something else).
    static var saved: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .dark
    }

    /// nil means "follow the Mac".
    var nsAppearance: NSAppearance? {
        switch self {
        case .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        case .system: nil
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

/// Owns the web view and exposes its state to the UI.
@MainActor
final class BrowserModel: NSObject, ObservableObject {
    static let homeURL = URL(string: "https://www.youtube.com")!

    /// Google's sign-in page for YouTube. After signing in it returns you to the YouTube home page.
    static let signInURL = URL(string:
        "https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26next%3D%252F"
    )!

    /// Cookies YouTube sets only when you're signed in to a Google account.
    private static let signedInCookieNames: Set<String> = ["SID", "__Secure-3PSID", "LOGIN_INFO"]

    /// Sites that open inside the app. Anything else opens in your default browser.
    private static let inAppHosts = [
        "youtube.com", "youtu.be", "youtube-nocookie.com",
        "google.com", "google.com.au", "googleusercontent.com", "gstatic.com",
    ]

    let webView: WKWebView

    /// Counts the data this app downloads, for the bandwidth badge.
    let bandwidth = BandwidthMonitor()

    /// On by default. Shows the bandwidth badge in the bottom-right corner (the counting always runs).
    /// Dark by default. YouTube follows this when its own Appearance setting is "Use device theme".
    @Published var appearance = AppAppearance.saved {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }

    @Published var showBandwidth = UserDefaults.standard.object(forKey: "showBandwidth") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showBandwidth, forKey: "showBandwidth") }
    }

    private static let bandwidthScript = BandwidthMonitor.pageScript(
        handlerName: "tubeyBandwidth", mediaHosts: ["googlevideo.com"]
    )

    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false

    /// On by default. Blocks Google's ad and analytics trackers (DoubleClick, Google Analytics, Tag Manager,
    /// ad services) and cookies from any other site (BlockRules.json).
    @Published var blockTrackers = BrowserModel.setting("blockTrackers", default: true) {
        didSet {
            UserDefaults.standard.set(blockTrackers, forKey: "blockTrackers")
            applyRules()
            webView.reload()
        }
    }

    /// Off by default: blocking watch-time pings also stops watch history and "resume where you left off".
    @Published var blockWatchHistory = UserDefaults.standard.bool(forKey: "blockWatchHistory") {
        didSet {
            UserDefaults.standard.set(blockWatchHistory, forKey: "blockWatchHistory")
            applyRules()
            webView.reload()
        }
    }

    static let subscriptionsURL = URL(string: "https://www.youtube.com/feed/subscriptions")!

    /// On by default. Hides Shorts shelves, tabs and links, and plays any Short as a normal video.
    @Published var hideShorts = BrowserModel.setting("hideShorts", default: true) {
        didSet { save(hideShorts, "hideShorts") }
    }

    /// On by default. Tubey opens on (and Home goes to) your Subscriptions page.
    @Published var focusMode = BrowserModel.setting("focusMode", default: true) {
        didSet { UserDefaults.standard.set(focusMode, forKey: "focusMode") }
    }

    /// Hides recommendations, sends YouTube's Home feed to Subscriptions, turns off autoplay and uses
    /// Theater mode. Starts the same as Focus Mode did before the two were split.
    @Published var hideRecommendations = BrowserModel.setting(
        "hideRecommendations", default: BrowserModel.setting("focusMode", default: true)
    ) {
        didSet { save(hideRecommendations, "hideRecommendations") }
    }

    /// On by default. Skips sponsors, self-promotion and subscribe reminders using SponsorBlock.
    @Published var skipSponsors = BrowserModel.setting("skipSponsors", default: true) {
        didSet { save(skipSponsors, "skipSponsors") }
    }

    /// Off by default. Also skips intros and outros (only applies when skipSponsors is on).
    @Published var skipIntrosAndOutros = BrowserModel.setting("skipIntrosAndOutros", default: false) {
        didSet { save(skipIntrosAndOutros, "skipIntrosAndOutros") }
    }

    /// On by default. Shows dislike counts from the Return YouTube Dislike community service.
    @Published var showDislikes = BrowserModel.setting("showDislikes", default: true) {
        didSet { save(showDislikes, "showDislikes") }
    }

    /// On by default. Hides YouTube Playables (mini-games).
    @Published var hidePlayables = BrowserModel.setting("hidePlayables", default: true) {
        didSet { save(hidePlayables, "hidePlayables") }
    }

    /// On by default. Swaps clickbait titles and thumbnails for DeArrow community ones.
    @Published var showDeArrow = BrowserModel.setting("showDeArrow", default: true) {
        didSet { save(showDeArrow, "showDeArrow") }
    }

    /// The video that's playing (for the menu bar player and the Picture in Picture button).
    let nowPlaying = NowPlaying()

    /// On by default. The mini player in the menu bar.
    @Published var showMenuBarPlayer = BrowserModel.setting("showMenuBarPlayer", default: true) {
        didSet { UserDefaults.standard.set(showMenuBarPlayer, forKey: "showMenuBarPlayer") }
    }

    /// Clean view switches, off by default.
    @Published var hideComments = BrowserModel.setting("hideComments", default: false) {
        didSet { save(hideComments, "hideComments") }
    }
    @Published var hideEndCards = BrowserModel.setting("hideEndCards", default: false) {
        didSet { save(hideEndCards, "hideEndCards") }
    }
    @Published var hideLiveChat = BrowserModel.setting("hideLiveChat", default: false) {
        didSet { save(hideLiveChat, "hideLiveChat") }
    }
    /// On by default. Hides the "Latest / All subscriptions" bar so your Subscriptions videos sit higher.
    @Published var hideFeedHeader = BrowserModel.setting("hideFeedHeader", default: true) {
        didSet { save(hideFeedHeader, "hideFeedHeader") }
    }

    /// On by default. Answers YouTube's "Video paused. Continue watching?" prompt for you.
    @Published var autoDismissStillWatching = BrowserModel.setting("autoDismissStillWatching", default: true) {
        didSet { save(autoDismissStillWatching, "autoDismissStillWatching") }
    }

    /// Speed and quality applied when each video starts.
    @Published var defaultSpeed = PlaybackSpeed.saved {
        didSet {
            UserDefaults.standard.set(defaultSpeed.rawValue, forKey: "defaultSpeed")
            applyUserScripts()
            webView.reload()
        }
    }
    @Published var videoQuality = VideoQuality.saved {
        didSet {
            UserDefaults.standard.set(videoQuality.rawValue, forKey: "videoQuality")
            applyUserScripts()
            webView.reload()
        }
    }

    nonisolated private static func setting(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }

    /// Saves a toggle and reloads the page so the change takes effect.
    private func save(_ value: Bool, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
        applyUserScripts()
        webView.reload()
    }

    private var observations: [NSKeyValueObservation] = []
    private var trackerRules: WKContentRuleList?
    private var watchHistoryRules: WKContentRuleList?

    override init() {
        let config = WKWebViewConfiguration()
        // The default data store is saved to disk, so you stay signed in between launches.
        config.websiteDataStore = .default()
        config.preferences.isElementFullscreenEnabled = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Picture in picture is off by default in app web views on the Mac (Safari turns it on).
        // This WebKit setting isn't public, so only set it if this macOS version has it.
        if config.preferences.responds(to: NSSelectorFromString("_setAllowsPictureInPictureMediaPlayback:")) {
            config.preferences.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        }

        webView = WKWebView(frame: .zero, configuration: config)
        // Present as Safari so YouTube and Google sign-in serve the full desktop site.
        webView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true
        // No zooming: pinch, smart zoom (two-finger double-tap) and page zoom are all off,
        // so YouTube always fits the window at its normal size.
        webView.allowsMagnification = false
        webView.magnification = 1
        webView.pageZoom = 1
        // Force dark mode: YouTube's default "device theme" follows this,
        // and the black background stops white flashes while pages load.
        webView.appearance = AppAppearance.saved.nsAppearance
        webView.underPageBackgroundColor = AppAppearance.saved == .light ? .white : .black
        // Don't paint a white background before YouTube loads, so the dark window shows through instead.
        // This WebKit setting isn't public, so only set it if this macOS version has it.
        if webView.responds(to: NSSelectorFromString("_setDrawsBackground:")) {
            webView.setValue(false, forKey: "drawsBackground")
        }

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.configuration.userContentController.add(bandwidth, name: "tubeyBandwidth")
        // Lets the SponsorBlock page script ask the app to look up segments.
        webView.configuration.userContentController
            .addScriptMessageHandler(self, contentWorld: .page, name: "tubeySponsorBlock")
        // Lets the dislikes page script ask the app to look up a video's dislike count.
        webView.configuration.userContentController
            .addScriptMessageHandler(self, contentWorld: .page, name: "tubeyDislikes")
        // Lets the DeArrow page script ask the app for community titles and thumbnails.
        webView.configuration.userContentController
            .addScriptMessageHandler(self, contentWorld: .page, name: "tubeyDeArrow")
        // The playing video, for the menu bar player and the Picture in Picture button.
        webView.configuration.userContentController.add(nowPlaying, name: "tubeyNowPlaying")
        nowPlaying.webView = webView

        observations = [
            webView.observe(\.canGoBack) { [weak self] _, _ in
                Task { @MainActor in self?.syncState() }
            },
            webView.observe(\.canGoForward) { [weak self] _, _ in
                Task { @MainActor in self?.syncState() }
            },
            webView.observe(\.isLoading) { [weak self] _, _ in
                Task { @MainActor in self?.syncState() }
            },
        ]

        applyUserScripts()
        // Keep the web view hidden until YouTube starts drawing, so launch shows the dark window
        // instead of a blank white view.
        webView.isHidden = true
        openStartPage()
    }

    /// On launch: YouTube if you're signed in, otherwise straight to Google sign-in.
    private func openStartPage() {
        Task {
            // Turn tracker blocking on before the first page loads.
            trackerRules = await Self.compileRules(named: "BlockRules")
            watchHistoryRules = await Self.compileRules(named: "WatchHistoryRules")
            applyRules()

            // Make YouTube's own theme match Tubey's Appearance setting before the first page loads.
            await syncYouTubeTheme()

            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            let signedIn = cookies.contains {
                $0.domain.hasSuffix("youtube.com") && Self.signedInCookieNames.contains($0.name)
            }
            webView.load(URLRequest(url: signedIn ? startURL : Self.signInURL))
        }
    }

    // MARK: - Actions

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
    func goHome() { webView.load(URLRequest(url: startURL)) }

    /// In Focus mode "home" is your Subscriptions feed rather than the recommendations page.
    private var startURL: URL { focusMode ? Self.subscriptionsURL : Self.homeURL }
    func signIn() { webView.load(URLRequest(url: Self.signInURL)) }

    /// Pops the playing video into a floating picture-in-picture window, or brings it back.
    func togglePictureInPicture() {
        let script = """
        (function () {
          const videos = Array.from(document.querySelectorAll('video'));
          const v = videos.find(x => !x.paused) || document.querySelector('#movie_player video') || videos[0];
          if (!v) return 'no-video';
          v.disablePictureInPicture = false;
          if (v.webkitSupportsPresentationMode && !v.webkitSupportsPresentationMode('picture-in-picture')) {
            return 'not-supported-by-webview';
          }
          if (v.webkitSetPresentationMode) {
            const inPip = v.webkitPresentationMode === 'picture-in-picture';
            v.webkitSetPresentationMode(inPip ? 'inline' : 'picture-in-picture');
            return 'ok';
          }
          if (document.pictureInPictureElement) { document.exitPictureInPicture(); return 'ok'; }
          if (v.requestPictureInPicture) { v.requestPictureInPicture(); return 'ok'; }
          return 'unsupported';
        })();
        """
        webView.evaluateJavaScript(script) { result, error in
            let outcome = (result as? String) ?? "error: \(error?.localizedDescription ?? "unknown")"
            print("Tubey: picture in picture → \(outcome)")
            if outcome != "ok" {
                NSSound.beep()
            }
        }
    }

    // MARK: - Appearance

    private func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
        webView.appearance = appearance.nsAppearance
        webView.underPageBackgroundColor = appearance == .light ? .white : .black
        // Switch YouTube's own theme setting, then reload so the page comes back in the new theme.
        // (The page script double-checks on load and fixes it if YouTube put its old choice back.)
        applyUserScripts()
        themeTask?.cancel()
        themeTask = Task {
            await syncYouTubeTheme()
            guard !Task.isCancelled else { return }
            webView.reload()
        }
    }

    /// The latest theme switch, so clicking quickly between modes doesn't leave an older one finishing last.
    private var themeTask: Task<Void, Never>?

    /// YouTube keeps its own Appearance choice in the "f6" field of its PREF cookie:
    /// the 0x400 flag means Dark, 0x80000 means Light, and neither means "Use device theme".
    /// This sets that flag to match Tubey's Appearance setting, keeping YouTube's other settings.
    private func syncYouTubeTheme() async {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let prefs = await store.allCookies().filter { $0.name == "PREF" && $0.domain.hasSuffix("youtube.com") }
        // YouTube can end up with more than one PREF cookie (e.g. ".youtube.com" and "www.youtube.com").
        // Keep the main one and remove the rest, so an old copy can't override the new theme.
        let existing = prefs.first { $0.domain == ".youtube.com" } ?? prefs.first
        for extra in prefs where extra.domain != ".youtube.com" || extra !== existing {
            await store.deleteCookie(extra)
        }
        var fields: [(String, String)] = (existing?.value ?? "").split(separator: "&").compactMap { part in
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            return pair.count == 2 ? (pair[0], pair[1]) : nil
        }
        var flags = UInt64(fields.first { $0.0 == "f6" }?.1 ?? "0", radix: 16) ?? 0
        flags &= ~UInt64(0x400 | 0x80000)
        switch appearance {
        case .dark: flags |= 0x400
        case .light: flags |= 0x80000
        case .system: break
        }
        fields.removeAll { $0.0 == "f6" }
        if flags != 0 { fields.insert(("f6", String(flags, radix: 16)), at: 0) }
        guard !fields.isEmpty else {
            if let existing { await store.deleteCookie(existing) }
            return
        }
        let properties: [HTTPCookiePropertyKey: Any] = [
            .name: "PREF",
            .value: fields.map { "\($0.0)=\($0.1)" }.joined(separator: "&"),
            .domain: ".youtube.com",
            .path: "/",
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 400),
        ]
        if let cookie = HTTPCookie(properties: properties) { await store.setCookie(cookie) }
    }

    // MARK: - Page features (Hide Shorts, Focus mode, SponsorBlock)

    private func applyUserScripts() {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(
            WKUserScript(source: Self.bandwidthScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        var scripts: [String?] = []
        if hideShorts { scripts.append(PageScripts.hideShorts) }
        scripts.append(hideRecommendations ? PageScripts.hideRecommendations : PageScripts.leaveFocusTheater)
        if skipSponsors { scripts.append(PageScripts.sponsorBlock) }
        scripts.append(TubeyFeatures.themeScript(mode: appearance.rawValue))
        if showDislikes { scripts.append(TubeyFeatures.dislikesScript) }
        if showDeArrow { scripts.append(DeArrow.pageScript) }
        if hidePlayables { scripts.append(TubeyFeatures.hidePlayablesScript) }
        scripts.append(NowPlaying.pageScript)
        scripts.append(TubeyFeatures.cleanViewScript(
            hideComments: hideComments, hideEndCards: hideEndCards, hideLiveChat: hideLiveChat,
            hideFeedHeader: hideFeedHeader))
        scripts.append(TubeyFeatures.playerTweaksScript(
            speed: defaultSpeed.rawValue, quality: videoQuality.rawValue, autoDismiss: autoDismissStillWatching))
        for case let source? in scripts {
            controller.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }
    }

    /// A youtube.com/shorts/ID address turned into the normal youtube.com/watch?v=ID page.
    private static func watchURL(forShort url: URL) -> URL? {
        guard let host = url.host?.lowercased(), host.hasSuffix("youtube.com") else { return nil }
        let parts = url.pathComponents  // ["/", "shorts", "ID"]
        guard parts.count >= 3, parts[1] == "shorts" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(parts[2])")
    }

    // MARK: - Tracker blocking

    /// Uses the same rule format as Safari content blockers. Edit BlockRules.json to add or remove rules.
    private func applyRules() {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        if blockTrackers, let trackerRules { controller.add(trackerRules) }
        if blockWatchHistory, let watchHistoryRules { controller.add(watchHistoryRules) }
    }

    private static func compileRules(named name: String) async -> WKContentRuleList? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let json = try? String(contentsOf: url, encoding: .utf8) else {
            print("Tubey: \(name).json not found")
            return nil
        }
        do {
            return try await WKContentRuleListStore.default()
                .compileContentRuleList(forIdentifier: name, encodedContentRuleList: json)
        } catch {
            print("Tubey: couldn't load \(name).json: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func syncState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
    }

    private static func opensInApp(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        return inAppHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// YouTube wraps outside links as youtube.com/redirect?q=<real link>.
    private static func externalTarget(of url: URL) -> URL? {
        if let host = url.host?.lowercased(),
           host.hasSuffix("youtube.com"),
           url.path == "/redirect",
           let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "q" })?.value,
           let target = URL(string: q) {
            return target
        }
        if let scheme = url.scheme, scheme == "http" || scheme == "https", !opensInApp(url) {
            return url
        }
        return nil
    }
}

// MARK: - SponsorBlock and dislikes bridge

extension BrowserModel: WKScriptMessageHandlerWithReply {
    /// Called by the page scripts with a video ID; replies with the segments to skip,
    /// or the dislike count.
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) async -> (Any?, String?) {
        if message.name == "tubeyDeArrow" {
            guard showDeArrow, let ids = message.body as? [String], !ids.isEmpty else { return ([String: Any](), nil) }
            let branding = await DeArrow.branding(for: ids)
            let titles = branding.values.compactMap { $0["title"] as? String }
            print("Tubey: DeArrow checked \(ids.count) video(s): \(titles.count) new title(s), "
                  + "\(branding.values.filter { $0["time"] != nil }.count) new thumbnail(s)"
                  + (titles.isEmpty ? "" : " — e.g. “\(titles.prefix(3).joined(separator: "”, “"))”"))
            return (branding, nil)
        }

        guard let videoID = message.body as? String else { return (nil, nil) }

        if message.name == "tubeyDislikes" {
            guard showDislikes, let dislikes = await ReturnYouTubeDislike.dislikes(videoID: videoID) else {
                return (nil, nil)
            }
            return (dislikes, nil)
        }

        guard message.name == "tubeySponsorBlock", skipSponsors else {
            return ([[String: Any]](), nil)
        }
        var categories = ["sponsor", "selfpromo", "interaction"]
        if skipIntrosAndOutros { categories += ["intro", "outro"] }
        let segments = await SponsorBlock.segments(videoID: videoID, categories: categories)
        print("Tubey: SponsorBlock found \(segments.count) segment(s) to skip in video \(videoID)")
        return (segments, nil)
    }
}

// MARK: - WebKit delegates

extension BrowserModel: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        webView.isHidden = false
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        if isMainFrame, hideShorts,
           let url = navigationAction.request.url,
           let watch = Self.watchURL(forShort: url) {
            webView.load(URLRequest(url: watch))
            return .cancel
        }
        if isMainFrame,
           navigationAction.navigationType == .linkActivated
            || navigationAction.request.url?.path == "/redirect",
           let url = navigationAction.request.url,
           let external = Self.externalTarget(of: url) {
            NSWorkspace.shared.open(external)
            return .cancel
        }
        return .allow
    }

    /// Links that try to open a new window load in this one instead (or in your browser if external).
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            if let external = Self.externalTarget(of: url) {
                NSWorkspace.shared.open(external)
            } else {
                webView.load(navigationAction.request)
            }
        }
        return nil
    }
}
