import CryptoKit
import Foundation

/// Replaces clickbait titles and thumbnails with ones written by the DeArrow community
/// (made by the SponsorBlock team).
///
/// For privacy, title lookups only send the first 4 characters of a hash of each video ID,
/// like SponsorBlock. Replacement thumbnails are loaded from DeArrow's thumbnail server.
enum DeArrow {
    /// For each video with a trusted community title and/or thumbnail:
    /// ["title": String, "time": seconds into the video for the thumbnail].
    static func branding(for videoIDs: [String]) async -> [String: [String: Any]] {
        let groups = Dictionary(grouping: Set(videoIDs)) { prefix(of: $0) }
        return await withTaskGroup(of: [String: [String: Any]].self) { group in
            for (prefix, ids) in groups {
                group.addTask { await lookUp(prefix: prefix, videoIDs: Set(ids)) }
            }
            var result: [String: [String: Any]] = [:]
            for await part in group {
                result.merge(part) { first, _ in first }
            }
            return result
        }
    }

    private static func prefix(of videoID: String) -> String {
        let hash = SHA256.hash(data: Data(videoID.utf8)).map { String(format: "%02x", $0) }.joined()
        return String(hash.prefix(4))
    }

    private static func lookUp(prefix: String, videoIDs: Set<String>) async -> [String: [String: Any]] {
        guard let url = URL(string: "https://sponsor.ajay.app/api/branding/\(prefix)") else { return [:] }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // 404 just means nobody has submitted anything for these videos.
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let videos = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
            var result: [String: [String: Any]] = [:]
            for id in videoIDs {
                guard let video = videos[id] as? [String: Any] else { continue }
                var branding: [String: Any] = [:]
                // The best submission comes first. Only use it if it's trusted and isn't just the original.
                if let best = (video["titles"] as? [[String: Any]])?.first, isTrusted(best),
                   let title = best["title"] as? String, !title.isEmpty {
                    branding["title"] = clean(title)
                }
                if let best = (video["thumbnails"] as? [[String: Any]])?.first, isTrusted(best),
                   let time = (best["timestamp"] as? NSNumber)?.doubleValue {
                    branding["time"] = time
                }
                if !branding.isEmpty { result[id] = branding }
            }
            return result
        } catch {
            print("Tubey: DeArrow lookup failed: \(error.localizedDescription)")
            return [:]
        }
    }

    private static func isTrusted(_ submission: [String: Any]) -> Bool {
        if submission["original"] as? Bool == true { return false }
        if submission["locked"] as? Bool == true { return true }
        return ((submission["votes"] as? NSNumber)?.intValue ?? -1) >= 0
    }

    /// A ">" before a word tells DeArrow's auto-formatter to leave that word alone; just remove it.
    private static func clean(_ title: String) -> String {
        title.replacingOccurrences(of: #"(^|\s)>(?=\S)"#, with: "$1", options: .regularExpression)
    }

    /// Finds video titles and thumbnails on the page, asks the app for DeArrow replacements, and swaps them in.
    /// Hovering a replaced title shows the original.
    static let pageScript = """
        (() => {
          if (window.__tubeyDeArrow) return;
          window.__tubeyDeArrow = true;
          const handler = window.webkit && window.webkit.messageHandlers &&
                          window.webkit.messageHandlers.tubeyDeArrow;
          if (!handler) return;

          // A small "DeArrow" tag in front of every title it has replaced, so you can see it working.
          const addTagStyle = () => {
            if (document.getElementById('tubey-dearrow-tag')) return;
            const style = document.createElement('style');
            style.id = 'tubey-dearrow-tag';
            style.textContent = '[data-tubey-de-arrow]::before { content: "DeArrow"; display: inline-block; ' +
              'font-size: 10px; font-weight: 600; line-height: 14px; padding: 0 5px; margin-right: 6px; ' +
              'border-radius: 4px; vertical-align: 2px; background: rgba(204, 0, 0, 0.85); color: #fff; }';
            (document.head || document.documentElement).appendChild(style);
          };
          addTagStyle();
          document.addEventListener('DOMContentLoaded', addTagStyle);

          const found = new Map();     // video ID -> { title, time } or null when there's nothing
          const asking = new Set();
          const failedThumbs = new Set();

          const idFrom = (href) => {
            try {
              const url = new URL(href, location.href);
              if (url.pathname === '/watch') return url.searchParams.get('v');
              const short = url.pathname.match(/^\\/shorts\\/([\\w-]{11})/);
              return short ? short[1] : null;
            } catch (e) { return null; }
          };

          const thumbURL = (id, time) =>
            'https://dearrow-thumb.ajay.app/api/v1/getThumbnail?videoID=' + encodeURIComponent(id) + '&time=' + time;

          // Title elements in the feeds, search results, sidebar, playlists and the watch page.
          const titleTargets = () => {
            const targets = [];
            document.querySelectorAll(
              '#video-title, #video-title-link, a[class*="lockup-metadata"][class*="title"], ' +
              'a[class*="LockupMetadataViewModelTitle"], h3 a[href*="/watch?v="], h3 a[href^="/shorts/"]'
            ).forEach((el) => {
              if (el.querySelector('#video-title')) return;
              const link = el.closest('a[href]') || el.querySelector('a[href]');
              const id = link && idFrom(link.getAttribute('href'));
              if (!id) return;
              const text = el.children.length
                ? el.querySelector('yt-formatted-string, .yt-core-attributed-string, span') || el
                : el;
              targets.push({ id, text, link });
            });
            const id = location.pathname === '/watch' ? new URLSearchParams(location.search).get('v') : null;
            const heading = document.querySelector('ytd-watch-metadata #title h1 yt-formatted-string, ytd-watch-metadata h1');
            if (id && heading) targets.push({ id, text: heading, link: null });
            return targets;
          };

          const thumbTargets = () => {
            const targets = [];
            document.querySelectorAll('a[href*="/watch?v="] img, a[href^="/shorts/"] img').forEach((img) => {
              if (img.closest('#avatar, yt-avatar-shape, .yt-spec-avatar-shape')) return;
              const link = img.closest('a[href]');
              const id = link && idFrom(link.getAttribute('href'));
              if (id) targets.push({ id, img });
            });
            return targets;
          };

          const applyTitle = ({ id, text, link }) => {
            const info = found.get(id);
            if (!info || !info.title) {
              // A reused element that used to show another video's replacement: put YouTube's text back.
              if (text.dataset.tubeyDeArrow && text.dataset.tubeyDeArrow !== id) {
                delete text.dataset.tubeyDeArrow;
              }
              return;
            }
            if (text.dataset.tubeyDeArrow === id && text.textContent === info.title) return;
            const original = text.textContent.trim();
            if (original && original !== info.title) {
              text.dataset.tubeyOriginal = original;
              const tip = info.title + '\\n(Original: ' + original + ')';
              (link || text).setAttribute('title', tip);
              if (link && link.getAttribute('aria-label')) link.setAttribute('aria-label', info.title);
            }
            text.textContent = info.title;
            text.dataset.tubeyDeArrow = id;
          };

          const applyThumb = ({ id, img }) => {
            const info = found.get(id);
            if (!info || info.time === undefined || info.time === null || failedThumbs.has(id)) return;
            const url = thumbURL(id, info.time);
            if (img.src === url || img.dataset.tubeyLoading === url) return;
            img.dataset.tubeyLoading = url;
            const test = new Image();
            test.onload = () => {
              if (test.naturalWidth > 1) { img.src = url; img.removeAttribute('srcset'); }
              else failedThumbs.add(id);
            };
            test.onerror = () => failedThumbs.add(id);   // not made yet on DeArrow's server: keep YouTube's
            test.src = url;
          };

          const ask = async (ids) => {
            ids.forEach((id) => asking.add(id));
            let result = {};
            try { result = (await handler.postMessage(ids)) || {}; } catch (e) {}
            ids.forEach((id) => { asking.delete(id); found.set(id, result[id] || null); });
            apply();
          };

          const apply = () => {
            const titles = titleTargets();
            const thumbs = thumbTargets();
            const missing = new Set();
            titles.concat(thumbs).forEach(({ id }) => {
              if (!found.has(id) && !asking.has(id)) missing.add(id);
            });
            if (missing.size) ask(Array.from(missing).slice(0, 60));
            titles.forEach(applyTitle);
            thumbs.forEach(applyThumb);
          };

          setInterval(apply, 1000);
        })();
        """
}
