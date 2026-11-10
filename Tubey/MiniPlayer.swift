import SwiftUI

/// The menu bar icon: a filled play symbol while something is playing.
struct MenuBarIcon: View {
    @ObservedObject var nowPlaying: NowPlaying

    var body: some View {
        Image(systemName: nowPlaying.isPlaying ? "play.rectangle.fill" : "play.rectangle")
    }
}

/// The mini player that drops down from the menu bar icon.
struct MiniPlayerView: View {
    @ObservedObject var nowPlaying: NowPlaying
    @EnvironmentObject private var browser: BrowserModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if nowPlaying.hasVideo {
                artwork
                details
                progress
                controls
            } else {
                nothing
            }
            Divider()
            HStack {
                Button("Open Tubey") { showTubey() }
                Spacer()
                Button("Hide Menu Bar Player") { browser.showMenuBarPlayer = false }
                    .help("You can turn it back on in Add-ons → Menu Bar Player")
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(14)
        .frame(width: 300)
    }

    private var artwork: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image = nowPlaying.artwork {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "play.rectangle").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { showTubey() }
        .help("Show in Tubey")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(nowPlaying.title.isEmpty ? "YouTube" : nowPlaying.title)
                .font(.headline)
                .lineLimit(2)
            Text(nowPlaying.isAd ? "Ad playing" : nowPlaying.channel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = nowPlaying.position(at: context.date)
            let duration = max(nowPlaying.duration, 1)
            VStack(spacing: 3) {
                ProgressView(value: min(position, duration), total: duration)
                    .progressViewStyle(.linear)
                HStack {
                    Text(Self.time(position))
                    Spacer()
                    Text(nowPlaying.duration > 0 ? "-" + Self.time(nowPlaying.duration - position) : "Live")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            control("backward.end.fill", "Previous (restarts the video)") { nowPlaying.previous() }
            control("gobackward.10", "Back 10 seconds") { nowPlaying.skip(by: -10) }
            control(nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                    nowPlaying.isPlaying ? "Pause" : "Play", size: 26) { nowPlaying.togglePlayPause() }
            control("goforward.10", "Forward 10 seconds") { nowPlaying.skip(by: 10) }
            control("forward.end.fill", "Next video") { nowPlaying.next() }
        }
        .frame(maxWidth: .infinity)
    }

    private func control(_ symbol: String, _ help: String, size: CGFloat = 17,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var nothing: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Nothing playing")
                .font(.headline)
            Text("Start a video in Tubey and it will show up here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func showTubey() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    /// e.g. 4:05 or 1:02:33
    static func time(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
