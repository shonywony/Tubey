import AppKit
import WebKit

/// Tracks the video that's playing, for the menu bar player.
///
/// A small page script reports the video's title, channel, length, position and play state;
/// the menu bar player's buttons are sent back to the page.
/// (Media keys, AirPods and Control Center are handled by WebKit itself, as in Safari. Tubey used to
/// handle them too, but doing both stopped Picture in Picture from opening.)
@MainActor
final class NowPlaying: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published private(set) var videoID: String?
    @Published private(set) var title = ""
    @Published private(set) var channel = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var isAd = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var artwork: NSImage?

    /// The position when the page last reported it; use `position(at:)` for the current position.
    private var reportedPosition: Double = 0
    private var reportedAt = Date()
    private var rate: Double = 1
    private var artworkFor: String?

    weak var webView: WKWebView?

    var hasVideo: Bool { videoID != nil }

    override init() {
        super.init()
    }

    /// The playback position right now (the page reports it every few seconds; this fills in between).
    func position(at date: Date = Date()) -> Double {
        let elapsed = isPlaying ? date.timeIntervalSince(reportedAt) * rate : 0
        let now = reportedPosition + elapsed
        return duration > 0 ? min(now, duration) : now
    }

    // MARK: - Commands (menu bar player)

    func togglePlayPause() { send("toggle") }
    func play() { send("play") }
    func pause() { send("pause") }
    func next() { send("next") }
    func previous() { send("previous") }
    func skip(by seconds: Double) { send("skip", seconds) }
    func seek(to seconds: Double) { send("seek", seconds) }

    private func send(_ command: String, _ value: Double = 0) {
        webView?.evaluateJavaScript("window.__tubeyMedia && window.__tubeyMedia('\(command)', \(value))")
    }

    // MARK: - Updates from the page

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let state = message.body as? [String: Any], let id = state["id"] as? String else {
            clear()
            return
        }
        videoID = id
        title = state["title"] as? String ?? ""
        channel = state["channel"] as? String ?? ""
        isPlaying = state["playing"] as? Bool ?? false
        isAd = state["ad"] as? Bool ?? false
        duration = (state["duration"] as? NSNumber)?.doubleValue ?? 0
        rate = (state["rate"] as? NSNumber)?.doubleValue ?? 1
        reportedPosition = (state["position"] as? NSNumber)?.doubleValue ?? 0
        reportedAt = Date()
        if artworkFor != id { loadArtwork(for: id) }
    }

    private func clear() {
        guard videoID != nil else { return }
        videoID = nil
        title = ""
        channel = ""
        isPlaying = false
        isAd = false
        duration = 0
        artwork = nil
        artworkFor = nil
    }

    private func loadArtwork(for id: String) {
        artworkFor = id
        artwork = nil
        guard let url = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg") else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data), artworkFor == id else { return }
            artwork = Self.cropTo16x9(image)
        }
    }

    /// YouTube's "hqdefault" thumbnails are 4:3 with black bars; trim them to the 16:9 picture.
    private static func cropTo16x9(_ image: NSImage) -> NSImage {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let width = CGFloat(cg.width)
        let height = width * 9 / 16
        guard height < CGFloat(cg.height) else { return image }
        let rect = CGRect(x: 0, y: (CGFloat(cg.height) - height) / 2, width: width, height: height)
        guard let cropped = cg.cropping(to: rect) else { return image }
        return NSImage(cgImage: cropped, size: NSSize(width: width, height: height))
    }

    // MARK: - Page script

    /// Reports the playing video to the app, and carries out play/pause/next/previous/seek commands.
    static let pageScript = """
        (() => {
          if (window.__tubeyNowPlaying) return;
          window.__tubeyNowPlaying = true;
          const handler = window.webkit && window.webkit.messageHandlers &&
                          window.webkit.messageHandlers.tubeyNowPlaying;
          if (!handler) return;

          let lastPlayChange = 0;
          let lastVideoChange = 0;
          let lastKey = '';
          let lastID = null;

          const player = () => document.getElementById('movie_player');
          const video = () => document.querySelector('#movie_player video');

          const state = () => {
            const p = player();
            const v = video();
            if (!p || !v || !v.src) return null;
            let data = {};
            try { data = (p.getVideoData && p.getVideoData()) || {}; } catch (e) {}
            const fromURL = location.pathname === '/watch' ? new URLSearchParams(location.search).get('v') : null;
            const id = data.video_id || fromURL;
            if (!id) return null;
            const heading = document.querySelector('ytd-watch-metadata h1');
            const owner = document.querySelector('ytd-watch-metadata ytd-channel-name a');
            return {
              id,
              title: data.title || (heading ? heading.textContent.trim() : document.title.replace(/ - YouTube$/, '')),
              channel: data.author || (owner ? owner.textContent.trim() : ''),
              ad: p.classList.contains('ad-showing'),
              duration: isFinite(v.duration) ? v.duration : 0,
              position: v.currentTime || 0,
              playing: !v.paused && !v.ended,
              rate: v.playbackRate || 1
            };
          };

          const report = (force) => {
            const v = video();
            if (v && !v.__tubeyNowPlaying) {
              v.__tubeyNowPlaying = true;
              ['play', 'pause', 'ratechange', 'seeked', 'durationchange'].forEach((name) =>
                v.addEventListener(name, () => {
                  if (name === 'play' || name === 'pause') lastPlayChange = Date.now();
                  report(true);
                }));
            }
            const s = state();
            if (s && s.id !== lastID) { lastID = s.id; lastVideoChange = Date.now(); }
            // Send when something changes; the position only every 10 seconds (the app fills in between).
            const key = JSON.stringify(s && Object.assign({}, s, { position: Math.floor(s.position / 10) }));
            if (!force && key === lastKey) return;
            lastKey = key;
            try { handler.postMessage(s); } catch (e) {}
          };

          window.__tubeyMedia = (command, value) => {
            const p = player();
            const v = video();
            if (!v) return;
            // WebKit can also answer the media keys itself; skip a second press that arrives straight after.
            const justToggled = Date.now() - lastPlayChange < 400;
            switch (command) {
              case 'toggle':
                if (justToggled) break;
                if (v.paused) v.play().catch(() => {}); else v.pause();
                break;
              case 'play': if (v.paused) v.play().catch(() => {}); break;
              case 'pause': if (!v.paused) v.pause(); break;
              case 'next':
                if (Date.now() - lastVideoChange < 1500) break;
                if (p && p.nextVideo) p.nextVideo();
                else { const b = document.querySelector('.ytp-next-button'); if (b) b.click(); }
                break;
              case 'previous':
                // Back to the start; if you're already at the start of a playlist video, the previous video.
                if (v.currentTime < 3 && new URLSearchParams(location.search).has('list') && p && p.previousVideo) {
                  if (Date.now() - lastVideoChange >= 1500) p.previousVideo();
                } else {
                  v.currentTime = 0;
                }
                break;
              case 'skip':
                v.currentTime = Math.max(0, Math.min(isFinite(v.duration) ? v.duration : Infinity, v.currentTime + value));
                break;
              case 'seek': v.currentTime = value; break;
            }
            setTimeout(() => report(true), 200);
          };

          setInterval(() => report(false), 1000);
        })();
        """
}
