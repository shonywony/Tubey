import SwiftUI

/// Tubey Help: explains every feature. Opened from Help → Tubey Help (⌘?) or the Help button in the toolbar.
struct HelpView: View {
    @State private var selection: HelpTopic.ID? = HelpTopic.all.first?.id
    @State private var columns = NavigationSplitViewVisibility.all
    @Environment(\.colorScheme) private var colorScheme

    /// Tubey red for headings: the icon's deep red on light backgrounds, a brighter red on dark ones
    /// so it stays easy to read.
    private var accent: Color {
        colorScheme == .dark ? Color(red: 1.0, green: 0.27, blue: 0.27) : .tubeyRed
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            // Rows draw their own highlight (a soft Tubey-red wash) instead of the Mac's blue selection bar.
            List(HelpTopic.all) { topic in
                let selected = topic.id == selection
                Button { selection = topic.id } label: {
                    Label {
                        Text(topic.title)
                            .foregroundStyle(.primary)
                            .fontWeight(selected ? .semibold : .regular)
                    } icon: {
                        Image(systemName: topic.symbol).foregroundStyle(accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(selected ? accent.opacity(0.18) : .clear)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                .listRowSeparator(.hidden)
            }
            .tint(.tubeyRed)
            // A little breathing room between the title bar and the first topic.
            .contentMargins(.top, 10, for: .scrollContent)
            // A plain light or dark panel, so only the title bar shows the red behind it.
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationSplitViewColumnWidth(min: 260, ideal: 265)
            // The topic list is always shown, so there's no need for the sidebar show/hide button.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            if let topic = HelpTopic.all.first(where: { $0.id == selection }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Label(topic.title, systemImage: topic.symbol)
                            .font(.largeTitle.bold())
                            .foregroundStyle(accent)
                            .padding(.bottom, 2)
                        Text(LocalizedStringKey(topic.intro))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        ForEach(topic.sections) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.heading).font(.headline).foregroundStyle(accent)
                                Text(LocalizedStringKey(section.body))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                Text("Choose a topic").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .navigationTitle("Tubey Help")
        // Keep the topic list open (it can't be collapsed).
        .onChange(of: columns) { _, _ in if columns != .all { columns = .all } }
        // The same red title bar as the main Tubey window, with white title text. The red sits behind
        // everything, and the panels above cover it, leaving it showing only in the title bar.
        .background(Color.tubeyRed.ignoresSafeArea())
        .toolbarBackground(Color.tubeyRed, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
        .tint(.tubeyRed)
        .frame(minWidth: 640, minHeight: 440)
    }
}

struct HelpTopic: Identifiable {
    struct Section: Identifiable {
        let heading: String
        let body: String
        var id: String { heading }
    }

    let title: String
    let symbol: String
    let intro: String
    let sections: [Section]
    var id: String { title }

    static let all: [HelpTopic] = [
        HelpTopic(
            title: "Getting Started", symbol: "star",
            intro: "Tubey is a native macOS client for YouTube, built with SwiftUI and WebKit. It layers privacy controls, playback tooling and a cleaner interface on top of the standard site.",
            sections: [
                .init(heading: "Signing in", body: """
                    If you're not signed in, Tubey opens straight to Google's sign-in page. You stay signed in \
                    between launches. To sign in again, choose **Navigate → Sign In with Google…**.
                    """),
                .init(heading: "The toolbar", body: """
                    **Back**, **Forward** and **Home** are on the left. On the right are **Reload** (it turns into \
                    a spinning wheel while a page loads), **Picture in Picture**, the **light/dark switch** \
                    (moon or sun), **Add-ons** and **Features** (where you switch Tubey's extras on and off), \
                    and **Help** (?).
                    """),
                .init(heading: "Keyboard shortcuts", body: """
                    • **⌘[** Back   • **⌘]** Forward   • **⌘R** Reload   • **⇧⌘H** Home
                    • **⇧⌘F** Hide Recommendations on/off   • **⇧⌘P** Picture in Picture
                    • **⌘?** or the **Help** button: this Help window
                    • **Play/Pause**, **Next** and **Previous** media keys: see *Media Keys & Now Playing*
                    YouTube's own shortcuts work too: **Space** or **K** play/pause, **J**/**L** back/forward \
                    10 seconds, **F** full screen, **T** Theater mode, **M** mute, **C** captions.
                    """),
                .init(heading: "Light and dark", body: """
                    Click the **moon/sun** button in the toolbar to switch between Dark and Light. It changes \
                    both Tubey's window and YouTube's own theme; the page reloads briefly when you switch.
                    """),
                .init(heading: "Changing a setting", body: """
                    Most switches reload the page so the change takes effect straight away. Your choices are \
                    remembered the next time you open Tubey.
                    """),
            ]),
        HelpTopic(
            title: "Features & Add-ons", symbol: "slider.horizontal.3",
            intro: "Tubey's switches live in two toolbar menus: **Features** and **Add-ons**.",
            sections: [
                .init(heading: "Features", body: """
                    How YouTube looks and plays: **Browsing** (Focus Mode), **Clean View** (hide recommendations, \
                    Shorts, Playables, comments, end cards and live chat) and **Playback** (Skip \
                    Sponsors, Still Watching, Default Speed, Video Quality).
                    """),
                .init(heading: "Add-ons", body: """
                    Extras on top of YouTube: **Show Dislikes**, **DeArrow**, the **Menu Bar Player** and the **Bandwidth \
                    Monitor**, plus a **Privacy** section with **Block Ad & Analytics Trackers** and **Block \
                    Watch-Time Tracking**.
                    """),
                .init(heading: "Using the menu", body: """
                    Each row has an icon, a short description and a switch. Click a switch (or anywhere on the \
                    row) to turn that feature on or off. The menu stays open, so you can change several at once. \
                    Rows with an arrow (Default Speed, Video Quality) open a list of choices.
                    """),
            ]),
        HelpTopic(
            title: "Media Keys & Now Playing", symbol: "playpause",
            intro: "Control YouTube from your keyboard, AirPods and Control Center, even when Tubey is in the background.",
            sections: [
                .init(heading: "What the keys do", body: """
                    • **Play/Pause** (F8 on most Mac keyboards) plays or pauses the video.
                    • **Next** (F9) goes to the next video in a playlist, or YouTube's “Up next” video.
                    • **Previous** (F7) goes back to the start of the video, or to the previous video in a \
                    playlist.
                    On a laptop you may need to hold **fn**, depending on your keyboard settings.
                    """),
                .init(heading: "AirPods and headphones", body: """
                    Press the stem (or headphone button) once to play/pause, twice for the next video, and \
                    three times to go back.
                    """),
                .init(heading: "Control Center", body: """
                    Open **Control Center** and look for **Now Playing**: it shows the video that's playing \
                    in Tubey, with play/pause and skip buttons.
                    """),
                .init(heading: "Why the keys sometimes control another app", body: """
                    Your Mac sends the media keys to whichever app played audio most recently. If Music or \
                    Spotify grabs them, just start the video in Tubey once (click play or press Space) and the \
                    keys come back to Tubey.
                    """),
                .init(heading: "Always on", body: """
                    This is built in, the same way it works in Safari, so there's nothing to switch on.
                    """),
            ]),
        HelpTopic(
            title: "Menu Bar Player", symbol: "menubar.rectangle",
            intro: "A mini player in the menu bar at the top of your screen, handy when Tubey is behind other windows.",
            sections: [
                .init(heading: "Using it", body: """
                    Click the **▶︎ icon** in the menu bar (it fills in while a video is playing). You'll see the \
                    thumbnail, title, channel and progress, with buttons for **previous**, **back 10 seconds**, \
                    **play/pause**, **forward 10 seconds** and **next**. Click the thumbnail or **Open Tubey** to \
                    bring the Tubey window to the front.
                    """),
                .init(heading: "Hiding it", body: """
                    Click **Hide Menu Bar Player** at the bottom of the mini player, or switch off \
                    **Add-ons → Menu Bar Player**. Turn the same switch \
                    on to bring it back.
                    """),
                .init(heading: "Good to know", body: """
                    The mini player only works while Tubey is open. Closing Tubey's window quits the app, so \
                    videos never keep playing out of sight.
                    """),
            ]),
        HelpTopic(
            title: "Browsing", symbol: "scope",
            intro: "Cut the noise so YouTube shows what you came for.",
            sections: [
                .init(heading: "Focus Mode", body: """
                    Tubey opens on your **Subscriptions** page instead of YouTube's Home feed, and the \
                    **Home** button in the toolbar takes you there too. To hide recommendations as well, \
                    turn on **Hide Recommendations** in Clean View.
                    """),
            ]),
        HelpTopic(
            title: "Clean View", symbol: "text.bubble",
            intro: "Hide the parts of YouTube you don't want to see.",
            sections: [
                .init(heading: "Hide Recommendations (⇧⌘F)", body: """
                    Hides suggested videos everywhere: the Home feed, the “Up next” list beside videos, \
                    end-of-video suggestions and Explore/Trending. YouTube's Home feed goes to your \
                    **Subscriptions** instead, and autoplay is switched off. With the “Up next” column gone, \
                    videos open in **Theater mode** so they fill the window; press **T** to switch a video \
                    back to the normal size.
                    """),
                .init(heading: "Hide Shorts", body: """
                    Removes Shorts shelves, tabs and links. If you open a Short from a link, it plays as a \
                    normal video instead.
                    """),
                .init(heading: "Hide Playables", body: """
                    Removes YouTube Playables, the built-in mini-games: the shelf of games on Home, game \
                    tiles in your feeds, and the Playables link in the sidebar. If you open a Playables link, \
                    Tubey takes you to Home instead.
                    """),
                .init(heading: "Hide Comments", body: "Hides the comments section under videos."),
                .init(heading: "Hide End Cards", body: """
                    Hides the pop-up cards during videos and the grid of suggestions at the end.
                    """),
                .init(heading: "Hide Live Chat", body: "Hides the chat panel beside live streams and premieres."),
                .init(heading: "Hide Subscriptions Header", body: """
                    Removes the “Latest” bar with the **All subscriptions** button from the top of your \
                    Subscriptions page, so the videos start higher up. You can still reach the full list of \
                    channels from **Subscriptions** in YouTube's left sidebar.
                    """),
            ]),
        HelpTopic(
            title: "Playback", symbol: "play.circle",
            intro: "Make videos play the way you like, automatically.",
            sections: [
                .init(heading: "Skip Sponsors", body: """
                    Uses the free SponsorBlock community database to jump past sponsor reads, self-promotion \
                    and “like and subscribe” reminders. **Also Skip Intros & Outros** skips channel intros and \
                    end segments too.
                    """),
                .init(heading: "Auto-Dismiss “Still Watching?”", body: """
                    Clicks “Yes” for you when YouTube pauses to ask if you're still watching, so long playlists \
                    and music keep going.
                    """),
                .init(heading: "Default Speed", body: """
                    Every video starts at this speed (after any ads). You can still change the speed during a \
                    video with YouTube's settings button.
                    """),
                .init(heading: "Video Quality", body: """
                    Every video starts at this quality. If a video doesn't have it, Tubey picks the best one \
                    below it. **480p (Data Saver)** uses much less data; **Best Available** always picks the top.
                    """),
                .init(heading: "Picture in Picture (⇧⌘P)", body: """
                    Pops the video out into a small floating window that stays on top of other apps. The \
                    button is greyed out until a video is open. Press \
                    ⇧⌘P again, or use the window's own button, to bring it back.
                    """),
            ]),
        HelpTopic(
            title: "Add-ons", symbol: "puzzlepiece.extension",
            intro: "Handy additions to YouTube, in the toolbar's **Add-ons** menu.",
            sections: [
                .init(heading: "Show Dislikes", body: """
                    Shows a dislike count next to the 👎 button, from the Return YouTube Dislike project. It's \
                    an estimate based on its users' votes and YouTube's older public numbers.
                    """),
                .init(heading: "DeArrow", body: """
                    Replaces clickbait titles and thumbnails with clearer ones written by the DeArrow \
                    community (made by the people behind SponsorBlock). Only replacements that other people \
                    have voted for are used; otherwise you see YouTube's own. Changed titles have a small red \
                    **DeArrow** tag in front of them; **hover over one** to see the original. Thumbnails come from a frame of the video that the community picked.
                    """),
                .init(heading: "Bandwidth Monitor", body: """
                    The badge in the bottom-right corner shows your **download speed** on the left and the \
                    **data used this session** on the right. The session total starts at zero every time you \
                    open Tubey; click the badge to reset it sooner. The numbers are a close estimate.
                    """),
            ]),
        HelpTopic(
            title: "Privacy", symbol: "hand.raised",
            intro: "Tubey blocks common trackers and keeps lookups to community services private where it can.",
            sections: [
                .init(heading: "Block Ad & Analytics Trackers", body: """
                    On by default, in **Add-ons → Privacy**. Blocks Google's advertising and analytics \
                    trackers (DoubleClick, Google Analytics, Tag Manager and Google's ad services) along with \
                    YouTube's ad-measurement and event-logging pings, and stops any site other than YouTube \
                    and Google from setting cookies. Your sign-in, videos and recommendations keep working \
                    normally.
                    """),
                .init(heading: "Block Watch-Time Tracking", body: """
                    Also blocks the reports YouTube uses to record what you watch. This is more private, but \
                    it turns off your watch history and “resume where you left off”. Find it in **Add-ons → Privacy**.
                    """),
                .init(heading: "Community services", body: """
                    **SponsorBlock** and **DeArrow** lookups only send the first few characters of a scrambled \
                    version of the video ID, so they can't tell exactly what you're watching. DeArrow's \
                    replacement thumbnails are loaded by video ID. **Return YouTube Dislike** is sent the ID of \
                    the video you open. None of them get your Google account.
                    """),
                .init(heading: "Signing out completely", body: """
                    Tubey keeps its own sign-in, separate from Safari. To sign out, use your profile picture → \
                    **Sign out** on YouTube.
                    """),
            ]),
        HelpTopic(
            title: "Troubleshooting", symbol: "wrench.and.screwdriver",
            intro: "If something doesn't look right, try these first.",
            sections: [
                .init(heading: "A page looks wrong or a feature didn't kick in", body: """
                    Press **⌘R** to reload. If a switch doesn't seem to work, turn it off and on again.
                    """),
                .init(heading: "A feature has stopped working", body: """
                    YouTube changes its website from time to time, which can break features that hide or \
                    change parts of the page (Clean View, DeArrow, Dislikes). Those need a small \
                    update to Tubey.
                    """),
                .init(heading: "Media keys control another app", body: """
                    Play the video in Tubey once and the keys come back.
                    """),
                .init(heading: "No dislike count, skipped segments or DeArrow title", body: """
                    These come from community services. Newer or less popular videos may not have anything \
                    submitted yet, and the services are sometimes briefly unavailable.
                    """),
            ]),
        HelpTopic(
            title: "Credits", symbol: "heart",
            intro: "Tubey builds on the work of these community projects and tools. Thank you to everyone behind them.",
            sections: [
                .init(heading: "SponsorBlock", body: """
                    **Skip Sponsors** uses the SponsorBlock database, created by Ajay Ramachandran and kept \
                    up to date by its community of contributors. SponsorBlock data is licensed under \
                    CC BY-NC-SA 4.0. [sponsor.ajay.app](https://sponsor.ajay.app)
                    """),
                .init(heading: "DeArrow", body: """
                    **DeArrow** titles and thumbnails come from the DeArrow project, also by Ajay Ramachandran \
                    and its contributors, including its thumbnail service. DeArrow data is licensed under \
                    CC BY-NC-SA 4.0. [dearrow.ajay.app](https://dearrow.ajay.app)
                    """),
                .init(heading: "Return YouTube Dislike", body: """
                    **Show Dislikes** uses the Return YouTube Dislike API, a community project that estimates \
                    dislike counts. [returnyoutubedislike.com](https://returnyoutubedislike.com)
                    """),
                .init(heading: "Built with", body: """
                    Apple's **SwiftUI**, **AppKit**, **WebKit** and **MediaPlayer** frameworks, and \
                    **SF Symbols** for the icons.
                    """),
                .init(heading: "About these credits", body: """
                    Tubey doesn't include code from the projects above; it uses their free public services. \
                    YouTube is a service of Google LLC. Tubey isn't affiliated with or endorsed by YouTube, \
                    Google, or any of the projects listed here.
                    """),
            ]),
    ]
}
