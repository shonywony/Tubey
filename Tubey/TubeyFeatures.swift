import Foundation

/// Default playback speed, applied when each video starts (you can still change it mid-video).
enum PlaybackSpeed: Double, CaseIterable, Identifiable {
    case normal = 1.0
    case x125 = 1.25
    case x150 = 1.5
    case x175 = 1.75
    case x200 = 2.0

    var id: Double { rawValue }
    var title: String { self == .normal ? "Normal" : String(format: "%g×", rawValue) }

    static var saved: PlaybackSpeed {
        PlaybackSpeed(rawValue: UserDefaults.standard.double(forKey: "defaultSpeed")) ?? .normal
    }
}

/// Video quality lock, applied when each video starts. Raw values are YouTube's own quality names.
enum VideoQuality: String, CaseIterable, Identifiable {
    case auto
    case best
    case hd1080
    case hd720
    case large

    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .best: "Best Available"
        case .hd1080: "1080p"
        case .hd720: "720p"
        case .large: "480p (Data Saver)"
        }
    }

    static var saved: VideoQuality {
        VideoQuality(rawValue: UserDefaults.standard.string(forKey: "videoQuality") ?? "") ?? .auto
    }
}

/// Page scripts for Tubey's extra features: clean view, dislikes, and player tweaks.
enum TubeyFeatures {
    /// Hides comments, end cards, live chat and/or the Subscriptions header. Returns nil when nothing is hidden.
    static func cleanViewScript(hideComments: Bool, hideEndCards: Bool, hideLiveChat: Bool,
                                hideFeedHeader: Bool) -> String? {
        var css = ""
        if hideComments {
            css += "ytd-comments, ytd-watch-flexy #comments { display: none !important; }\n"
        }
        if hideEndCards {
            css += """
            .ytp-ce-element, .ytp-cards-teaser, .ytp-endscreen-content, .html5-endscreen,
            .ytp-fullscreen-grid, .ytp-fullscreen-grid-stills-container,
            .ytp-autonav-endscreen-countdown-overlay { display: none !important; }

            """
        }
        if hideFeedHeader {
            // The "Latest / All subscriptions" bar at the top of Subscriptions (a section with no videos in it).
            css += """
            ytd-browse[page-subtype="subscriptions"] ytd-rich-section-renderer:has(a[href^="/feed/channels"]):not(:has(ytd-rich-item-renderer, yt-lockup-view-model)) { display: none !important; }

            """
        }
        if hideLiveChat {
            css += "ytd-live-chat-frame, ytd-watch-flexy #chat-container, ytd-watch-flexy #chat { display: none !important; }\n"
        }
        guard !css.isEmpty,
              let data = try? JSONEncoder().encode(css),
              let literal = String(data: data, encoding: .utf8) else { return nil }
        return """
            (() => {
              const addStyle = () => {
                if (document.getElementById('tubey-clean-view')) return;
                const style = document.createElement('style');
                style.id = 'tubey-clean-view';
                style.textContent = \(literal);
                (document.head || document.documentElement).appendChild(style);
              };
              addStyle();
              document.addEventListener('DOMContentLoaded', addStyle);
            })();
            """
    }

    /// Hides YouTube Playables (the mini-games): the shelf on Home, game tiles, and the sidebar link.
    static let hidePlayablesScript = """
        (() => {
          const css = `
            ytd-rich-section-renderer:has(a[href^="/playables"]),
            ytd-rich-section-renderer:has(ytd-rich-shelf-renderer[is-playables]),
            ytd-rich-shelf-renderer[is-playables],
            ytd-rich-item-renderer:has(a[href^="/playables"]),
            ytd-shelf-renderer:has(a[href^="/playables"]),
            ytd-guide-entry-renderer:has(a[href^="/playables"]),
            ytd-mini-guide-entry-renderer:has(a[href^="/playables"]),
            yt-chip-cloud-chip-renderer:has(a[href^="/playables"]) { display: none !important; }`;
          const addStyle = () => {
            if (document.getElementById('tubey-hide-playables')) return;
            const style = document.createElement('style');
            style.id = 'tubey-hide-playables';
            style.textContent = css;
            (document.head || document.documentElement).appendChild(style);
          };
          addStyle();
          document.addEventListener('DOMContentLoaded', addStyle);
          // Opening the Playables page itself goes to Home instead.
          const leave = () => { if (location.pathname.startsWith('/playables')) location.replace('/'); };
          leave();
          setInterval(leave, 1000);
        })();
        """

    /// Default speed, quality lock and "Still watching?" auto-dismiss, checked once a second.
    static func playerTweaksScript(speed: Double, quality: String, autoDismiss: Bool) -> String {
        """
        (() => {
          if (window.__tubeyPlayerTweaks) return;
          window.__tubeyPlayerTweaks = true;
          const SPEED = \(speed);
          const QUALITY = '\(quality)';
          const DISMISS = \(autoDismiss);
          const ORDER = ['highres', 'hd2880', 'hd2160', 'hd1440', 'hd1080', 'hd720', 'large', 'medium', 'small', 'tiny'];

          const videoID = () =>
            location.pathname === '/watch' ? new URLSearchParams(location.search).get('v') : null;
          let appliedFor = null;

          // Set speed and quality once per video, after any ads, so you can still change them yourself.
          const applySettings = () => {
            const id = videoID();
            if (!id || appliedFor === id) return;
            const player = document.getElementById('movie_player');
            const video = player && player.querySelector('video');
            if (!player || !video || video.readyState < 1 || player.classList.contains('ad-showing')) return;
            try {
              const data = player.getVideoData && player.getVideoData();
              if (data && data.video_id && data.video_id !== id) return;
            } catch (e) {}

            if (SPEED !== 1) {
              try { player.setPlaybackRate(SPEED); } catch (e) { video.playbackRate = SPEED; }
            }
            if (QUALITY !== 'auto') {
              try {
                const levels = (player.getAvailableQualityLevels ? player.getAvailableQualityLevels() : [])
                  .filter(l => ORDER.includes(l));
                let q = QUALITY;
                if (q === 'best') {
                  q = levels[0];
                } else if (levels.length && !levels.includes(q)) {
                  // Not available for this video: use the best quality at or below the one you picked.
                  q = levels.find(l => ORDER.indexOf(l) >= ORDER.indexOf(QUALITY)) || levels[levels.length - 1];
                }
                if (q) {
                  if (player.setPlaybackQualityRange) player.setPlaybackQualityRange(q, q);
                  if (player.setPlaybackQuality) player.setPlaybackQuality(q);
                }
              } catch (e) {}
            }
            appliedFor = id;
          };

          // Click "Yes" on YouTube's "Video paused. Continue watching?" prompt.
          const dismissStillWatching = () => {
            if (!DISMISS) return;
            document.querySelectorAll('yt-confirm-dialog-renderer').forEach((dialog) => {
              if (dialog.offsetParent === null) return;
              const text = (dialog.innerText || '').toLowerCase();
              if (!text.includes('continue watching') && !text.includes('still watching')) return;
              const button = dialog.querySelector('#confirm-button button, #confirm-button');
              if (!button) return;
              button.click();
              const video = document.querySelector('#movie_player video');
              if (video && video.paused) video.play().catch(() => {});
            });
          };

          setInterval(() => { applySettings(); dismissStillWatching(); }, 1000);
        })();
        """
    }

    /// Makes YouTube's page follow Tubey's Appearance setting (Dark, Light or Match System).
    /// YouTube switches theme with a `dark` attribute on the page, so this sets or removes it,
    /// and puts it back if YouTube changes it. Calling it again just switches the mode.
    static func themeScript(mode: String) -> String {
        """
        (() => {
          window.__tubeyTheme = '\(mode)';

          // YouTube picks its theme from the f6 flags in its PREF cookie (0x400 dark, 0x80000 light).
          // YouTube sometimes writes its old choice back, so if the page loaded with the wrong theme,
          // fix the cookie and reload once (no more than once every 10 seconds, so it can't loop).
          try {
            if (location.hostname.endsWith('youtube.com')) {
              const match = document.cookie.match(/(?:^|; )PREF=([^;]*)/);
              const rest = [];
              let flags = 0;
              (match ? match[1] : '').split('&').filter(Boolean).forEach((part) => {
                const [key, value] = part.split('=');
                if (key === 'f6') flags = parseInt(value, 16) || 0;
                else rest.push(part);
              });
              const want = window.__tubeyTheme === 'dark' ? 0x400 : window.__tubeyTheme === 'light' ? 0x80000 : 0;
              if ((flags & (0x400 | 0x80000)) !== want) {
                flags = (flags & ~(0x400 | 0x80000)) | want;
                if (flags) rest.unshift('f6=' + flags.toString(16));
                const expires = new Date(Date.now() + 400 * 864e5).toUTCString();
                document.cookie = 'PREF=' + rest.join('&') + '; domain=.youtube.com; path=/; expires=' + expires + '; secure';
                const last = Number(sessionStorage.getItem('tubeyThemeFix') || 0);
                if (Date.now() - last > 10000) {
                  sessionStorage.setItem('tubeyThemeFix', String(Date.now()));
                  location.reload();
                  return;
                }
              }
            }
          } catch (e) {}

          if (window.__tubeyApplyTheme) { window.__tubeyApplyTheme(); return; }

          const media = window.matchMedia('(prefers-color-scheme: dark)');
          const wantDark = () =>
            window.__tubeyTheme === 'dark' || (window.__tubeyTheme === 'system' && media.matches);

          const apply = () => {
            const html = document.documentElement;
            if (!html) return;
            if (wantDark()) {
              if (!html.hasAttribute('dark')) html.setAttribute('dark', 'true');
            } else {
              ['dark', 'darker-dark-theme', 'darker-dark-theme-deprecate'].forEach((name) => {
                if (html.hasAttribute(name)) html.removeAttribute(name);
              });
            }
          };

          // Keep watching the page's root element, and re-apply whenever YouTube changes the theme marker.
          let watched = null;
          const observer = new MutationObserver(apply);
          const watch = () => {
            const html = document.documentElement;
            if (html && html !== watched) {
              watched = html;
              observer.observe(html, {
                attributes: true, attributeFilter: ['dark', 'darker-dark-theme', 'darker-dark-theme-deprecate']
              });
            }
            apply();
          };

          window.__tubeyApplyTheme = watch;
          watch();
          new MutationObserver(watch).observe(document, { childList: true });
          media.addEventListener('change', apply);
          document.addEventListener('DOMContentLoaded', watch);
        })();
        """
    }

    /// Shows the dislike count (from Return YouTube Dislike) next to the 👎 button.
    static let dislikesScript = """
        (() => {
          if (window.__tubeyDislikes) return;
          window.__tubeyDislikes = true;

          const videoID = () =>
            location.pathname === '/watch' ? new URLSearchParams(location.search).get('v') : null;
          let currentID = null;
          let count = null;

          const format = (n) => {
            const short = (v, unit) => (v >= 10 ? Math.round(v) : Math.round(v * 10) / 10) + unit;
            if (n >= 1e6) return short(n / 1e6, 'M');
            if (n >= 1e3) return short(n / 1e3, 'K');
            return String(n);
          };

          const findButton = () => document.querySelector(
            'ytd-watch-metadata dislike-button-view-model button, ' +
            '#top-level-buttons-computed dislike-button-view-model button, ' +
            '#segmented-dislike-button button');

          const render = () => {
            const button = findButton();
            if (!button) return;
            let label = button.querySelector('.tubey-dislikes');
            if (count === null) { if (label) label.remove(); return; }
            if (!label) {
              label = document.createElement('span');
              label.className = 'tubey-dislikes';
              label.style.cssText = 'margin-left:6px;font-size:14px;font-weight:500;white-space:nowrap;';
              button.appendChild(label);
              button.style.width = 'auto';
              button.style.paddingRight = '14px';
            }
            const text = format(count);
            if (label.textContent !== text) label.textContent = text;
          };

          const load = async () => {
            const id = videoID();
            if (id === currentID) return;
            currentID = id;
            count = null;
            render();
            if (!id) return;
            try {
              const result = await window.webkit.messageHandlers.tubeyDislikes.postMessage(id);
              if (currentID === id && typeof result === 'number') count = result;
            } catch (e) {}
            render();
          };

          setInterval(() => { load(); render(); }, 1000);
        })();
        """
}

/// Looks up a video's dislike count from the free Return YouTube Dislike community service.
enum ReturnYouTubeDislike {
    static func dislikes(videoID: String) async -> Int? {
        var components = URLComponents(string: "https://returnyoutubedislikeapi.com/votes")!
        components.queryItems = [URLQueryItem(name: "videoId", value: videoID)]
        guard let url = components.url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dislikes = json["dislikes"] as? Int else { return nil }
            return dislikes
        } catch {
            print("Tubey: Return YouTube Dislike lookup failed: \(error.localizedDescription)")
            return nil
        }
    }
}
