import Foundation

/// JavaScript that Tubey adds to YouTube pages.
/// YouTube switches pages without fully reloading, so each script listens for its
/// "yt-navigate-finish" event to re-apply itself.
enum PageScripts {
    /// Hides Shorts (HideShorts.css) and turns any /shorts/ID page into the normal video page.
    static let hideShorts = styleScript(cssFile: "HideShorts", styleID: "tubey-hide-shorts", extraJS: """
        const redirectShort = () => {
          const match = location.pathname.match(/^\\/shorts\\/([A-Za-z0-9_-]+)/);
          if (match) location.replace('/watch?v=' + match[1]);
        };
        redirectShort();
        window.addEventListener('yt-navigate-finish', redirectShort);
        window.addEventListener('popstate', redirectShort);
        """)

    /// Hides recommendations (FocusMode.css), sends Home to Subscriptions, and turns off autoplay.
    static let focusMode = styleScript(cssFile: "FocusMode", styleID: "tubey-focus-mode", extraJS: """
        const toSubscriptions = () => {
          if (location.pathname === '/') location.replace('/feed/subscriptions');
        };
        const autoplayOff = () => {
          const toggle = document.querySelector('.ytp-autonav-toggle-button[aria-checked="true"]');
          if (toggle) toggle.click();
        };
        toSubscriptions();
        setTimeout(autoplayOff, 3000);
        window.addEventListener('yt-navigate-finish', () => {
          toSubscriptions();
          setTimeout(autoplayOff, 1500);
        });
        """)

    /// Asks the app for SponsorBlock segments for each video, then jumps over them as they come up.
    static let sponsorBlock = """
        (() => {
          if (window.__tubeySponsorBlock) return;
          window.__tubeySponsorBlock = true;

          const labels = {
            sponsor: 'sponsor', selfpromo: 'self-promotion', interaction: 'subscribe reminder',
            intro: 'intro', outro: 'outro'
          };
          let segments = [];
          let currentID = null;
          let video = null;

          const videoID = () =>
            location.pathname === '/watch' ? new URLSearchParams(location.search).get('v') : null;

          const toast = (text) => {
            const host = document.getElementById('movie_player') || document.body;
            if (!host) return;
            const el = document.createElement('div');
            el.textContent = text;
            el.style.cssText = 'position:absolute;bottom:70px;left:50%;transform:translateX(-50%);' +
              'z-index:9999;background:rgba(0,0,0,.85);color:#fff;padding:8px 14px;border-radius:8px;' +
              'font:500 14px -apple-system,sans-serif;pointer-events:none;transition:opacity .4s';
            host.appendChild(el);
            setTimeout(() => { el.style.opacity = '0'; }, 2000);
            setTimeout(() => el.remove(), 2500);
          };

          const check = () => {
            if (!video || !segments.length) return;
            const player = document.getElementById('movie_player');
            if (player && player.classList.contains('ad-showing')) return;
            const t = video.currentTime;
            for (const s of segments) {
              if (t >= s.start && t < s.end - 0.5) {
                video.currentTime = s.end;
                toast('Skipped ' + (labels[s.category] || s.category));
                return;
              }
            }
          };

          const attach = () => {
            const v = document.querySelector('#movie_player video');
            if (v && v !== video) {
              if (video) video.removeEventListener('timeupdate', check);
              video = v;
              video.addEventListener('timeupdate', check);
            }
          };

          const load = async () => {
            attach();
            const id = videoID();
            if (id === currentID) return;
            currentID = id;
            segments = [];
            if (!id) return;
            try {
              const result = await window.webkit.messageHandlers.tubeySponsorBlock.postMessage(id);
              if (currentID === id && Array.isArray(result)) segments = result;
            } catch (e) {}
          };

          window.addEventListener('yt-navigate-finish', load);
          document.addEventListener('DOMContentLoaded', load);
          setInterval(attach, 2000);
        })();
        """

    /// Builds a script that keeps a CSS file from the app applied to the page, plus any extra JavaScript.
    private static func styleScript(cssFile: String, styleID: String, extraJS: String) -> String? {
        guard let url = Bundle.main.url(forResource: cssFile, withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8),
              let data = try? JSONEncoder().encode(css),
              let cssLiteral = String(data: data, encoding: .utf8) else {
            print("Tubey: \(cssFile).css not found")
            return nil
        }
        return """
            (() => {
              const css = \(cssLiteral);
              const addStyle = () => {
                if (document.getElementById('\(styleID)')) return;
                const style = document.createElement('style');
                style.id = '\(styleID)';
                style.textContent = css;
                (document.head || document.documentElement).appendChild(style);
              };
              addStyle();
              document.addEventListener('DOMContentLoaded', addStyle);
              window.addEventListener('yt-navigate-finish', addStyle);
            \(extraJS)
            })();
            """
    }
}
