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
        document.addEventListener('yt-navigate-finish', redirectShort);
        window.addEventListener('popstate', redirectShort);
        setInterval(redirectShort, 1000);
        """)

    /// Hides recommendations (FocusMode.css), sends YouTube's Home feed to Subscriptions (it would be empty),
    /// turns off autoplay, and opens videos in Theater mode.
    static let hideRecommendations = styleScript(cssFile: "FocusMode", styleID: "tubey-focus-mode", extraJS: """
        const toSubscriptions = () => {
          if (location.pathname === '/') location.replace('/feed/subscriptions');
        };
        const autoplayOff = () => {
          const toggle = document.querySelector('.ytp-autonav-toggle-button[aria-checked="true"]');
          if (toggle) toggle.click();
        };
        // With recommendations gone, switch videos to YouTube's Theater mode so the video fills the
        // window width instead of leaving an empty column. Done once per video, so you can switch it back.
        let theaterFor = null;
        const useTheater = () => {
          const id = location.pathname === '/watch' ? new URLSearchParams(location.search).get('v') : null;
          if (!id || theaterFor === id) return;
          const page = document.querySelector('ytd-watch-flexy');
          const button = document.querySelector('#movie_player .ytp-size-button');
          const video = document.querySelector('#movie_player video');
          if (!page || !button || !video || video.readyState < 1) return;
          theaterFor = id;
          if (page.hasAttribute('theater') || page.hasAttribute('fullscreen')) return;
          button.click();
          try { localStorage.setItem('tubeyTheater', '1'); } catch (e) {}
        };
        setInterval(useTheater, 1000);
        toSubscriptions();
        setTimeout(autoplayOff, 3000);
        const onNavigate = () => {
          toSubscriptions();
          setTimeout(autoplayOff, 1500);
        };
        window.addEventListener('yt-navigate-finish', onNavigate);
        document.addEventListener('yt-navigate-finish', onNavigate);
        """)

    /// Runs when Hide Recommendations is off: if it switched videos to Theater mode, switch back once.
    static let leaveFocusTheater = """
        (() => {
          if (window.__tubeyLeaveTheater) return;
          window.__tubeyLeaveTheater = true;
          const timer = setInterval(() => {
            let flagged = false;
            try { flagged = localStorage.getItem('tubeyTheater') === '1'; } catch (e) {}
            if (!flagged) { clearInterval(timer); return; }
            if (location.pathname !== '/watch') return;
            const page = document.querySelector('ytd-watch-flexy');
            const button = document.querySelector('#movie_player .ytp-size-button');
            const video = document.querySelector('#movie_player video');
            if (!page || !button || !video || video.readyState < 1) return;
            if (page.hasAttribute('theater') && !page.hasAttribute('fullscreen')) button.click();
            try { localStorage.removeItem('tubeyTheater'); } catch (e) {}
            clearInterval(timer);
          }, 1000);
        })();
        """

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
          document.addEventListener('yt-navigate-finish', load);
          document.addEventListener('DOMContentLoaded', load);
          // Backup: check once a second whether YouTube has switched to a different video.
          setInterval(() => {
            attach();
            if (videoID() !== currentID) load();
          }, 1000);
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
              document.addEventListener('yt-navigate-finish', addStyle);
            \(extraJS)
            })();
            """
    }
}
