import SwiftUI
import WebKit

/// Measures how much data this app's web page downloads, for the bandwidth badge.
///
/// macOS doesn't let a sandboxed app read the network usage of the web view's helper processes,
/// so the page itself reports what it receives: the video/audio handed to the player (almost all
/// of the traffic) plus pages, images, scripts and other files. The result is a close estimate.
@MainActor
final class BandwidthMonitor: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published private(set) var bytesPerSecond: Double = 0
    @Published private(set) var sessionBytes: Double = 0

    private var receivedSinceLastTick: Double = 0
    private var timer: Timer?

    override init() {
        super.init()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Clears the session total (clicking the badge does this).
    func reset() { sessionBytes = 0 }

    /// Once a second: update the speed, smoothed so it doesn't jump around too much.
    private func tick() {
        let smoothed = bytesPerSecond * 0.6 + receivedSinceLastTick * 0.4
        bytesPerSecond = smoothed < 100 ? 0 : smoothed
        receivedSinceLastTick = 0
    }

    /// The page script sends the number of bytes it received in the last second.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let bytes = (message.body as? NSNumber)?.doubleValue ?? 0
        guard bytes > 0, bytes.isFinite else { return }
        receivedSinceLastTick += bytes
        sessionBytes += bytes
    }

    /// e.g. 950 B, 4.2 MB, 312 MB, 1.3 GB
    nonisolated static func format(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytes
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        if unit == 0 { return "\(Int(value)) B" }
        return String(format: value < 10 ? "%.1f" : "%.0f", value) + " " + units[unit]
    }

    /// The page script that counts downloaded bytes and reports them to the app once a second.
    /// - handlerName: the message handler the app registered.
    /// - mediaHosts: the site's video servers; their downloads are counted via the player instead.
    nonisolated static func pageScript(handlerName: String, mediaHosts: [String]) -> String {
        let hosts = "[" + mediaHosts.map { "'\($0)'" }.joined(separator: ",") + "]"
        return """
        (() => {
          if (window.__appBandwidthMonitor) return;
          window.__appBandwidthMonitor = true;
          const handler = window.webkit && window.webkit.messageHandlers &&
                          window.webkit.messageHandlers.\(handlerName);
          if (!handler) return;

          let pending = 0;
          const add = (n) => { if (n > 0 && isFinite(n)) pending += n; };
          const mediaHosts = \(hosts);
          const isMedia = (url) => {
            try {
              const h = new URL(url, location.href).hostname;
              return mediaHosts.some(d => h === d || h.endsWith('.' + d));
            } catch (e) { return false; }
          };

          // 1. Video and audio data handed to the player (Media Source Extensions).
          let playerBytes = 0;
          if (window.SourceBuffer && !SourceBuffer.prototype.appendBuffer.__counted) {
            const original = SourceBuffer.prototype.appendBuffer;
            const counted = function (data) {
              try {
                const n = (data && (data.byteLength || (data.buffer && data.buffer.byteLength))) || 0;
                add(n);
                playerBytes += n;
              } catch (e) {}
              return original.apply(this, arguments);
            };
            counted.__counted = true;
            SourceBuffer.prototype.appendBuffer = counted;
          }

          // 2. If the player streams some other way, use WebKit's own media byte counters instead.
          const lastMediaCount = new WeakMap();
          const pollMediaElements = () => {
            if (playerBytes > 0) return;
            document.querySelectorAll('video, audio').forEach((el) => {
              const total = (el.webkitVideoDecodedByteCount || 0) + (el.webkitAudioDecodedByteCount || 0);
              const previous = lastMediaCount.get(el);
              if (previous !== undefined && total > previous) add(total - previous);
              lastMediaCount.set(el, total);
            });
          };

          // 3. Everything else: the page itself, images, scripts, styles and other files.
          try {
            new PerformanceObserver((list) => {
              for (const entry of list.getEntries()) {
                if (isMedia(entry.name)) continue;
                add(entry.transferSize || entry.encodedBodySize || 0);
              }
            }).observe({ type: 'resource', buffered: true });
            new PerformanceObserver((list) => {
              for (const entry of list.getEntries()) add(entry.transferSize || entry.encodedBodySize || 0);
            }).observe({ type: 'navigation', buffered: true });
          } catch (e) {}

          setInterval(() => {
            pollMediaElements();
            if (pending > 0) {
              const n = pending;
              pending = 0;
              try { handler.postMessage(n); } catch (e) {}
            }
          }, 1000);
        })();
        """
    }
}

/// The small "↓ 4.2 MB/s · 312 MB" badge in the bottom-right corner. Click it to reset the total.
struct BandwidthBadge: View {
    @ObservedObject var monitor: BandwidthMonitor
    /// The app's own colour (the same as its top bar).
    var tint: Color

    var body: some View {
        Button { monitor.reset() } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(BandwidthMonitor.format(monitor.bytesPerSecond) + "/s")
                Text("·")
                    .foregroundStyle(.white.opacity(0.6))
                Text(BandwidthMonitor.format(monitor.sessionBytes))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.9), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.18)))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .help("Data this app has downloaded since it opened (close estimate). Click to reset the total.")
    }
}
