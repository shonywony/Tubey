# Tubey

A simple Mac app that wraps youtube.com in its own window.

## Run it

1. Install **Xcode** from the Mac App Store (free) if you haven't already.
2. Unzip this folder and double-click `Tubey.xcodeproj`.
3. Press **⌘R** (or the ▶ button at the top left). The app builds and opens.

To keep a copy in Applications: in Xcode choose **Product → Show Build Folder in Finder**, open `Products/Debug`, and drag `Tubey.app` into Applications.

If Xcode shows a signing warning, click the **Tubey** project in the left sidebar, open **Signing & Capabilities**, and pick your Apple ID under *Team* (a free Apple ID is fine for running on your own Mac).

## Features

- Its own window and Dock icon, and it stays signed in between launches
- Opens straight to Google sign-in if you're signed out (also in the Navigate menu: "Sign In with Google…")
- Toolbar: Back, Forward, Home, Reload, Picture in Picture
- Keyboard shortcuts: ⌘[ back, ⌘] forward, ⌘R reload, ⇧⌘H home, ⇧⌘P picture in picture
- Trackpad swipe for back/forward, pinch to zoom
- Hides YouTube Shorts (on by default, toggle in View → Hide Shorts): removes Shorts shelves, the Shorts sidebar entry and channel tab, and Shorts mixed into feeds and search. Any Shorts link opens as a normal video page instead. Selectors live in `HideShorts.css`
- Focus mode (on by default, View → Focus Mode or ⇧⌘F): hides Home recommendations, the "Up next" sidebar, end-screen suggestions and recommendation shelves in search; Home goes to your Subscriptions; autoplay is turned off. Selectors live in `FocusMode.css`
- SponsorBlock (on by default, Video menu): skips sponsor reads, self-promotion and subscribe reminders using the free community SponsorBlock database, with a small "Skipped sponsor" note. Optional: also skip intros and outros. Lookups are private (only a 4-character hash prefix of the video ID is sent)
- Bandwidth monitor (bottom-right corner, View → Show Bandwidth Monitor): live download speed and data used this session by this app only. Click it to reset the total. It's a close estimate: it counts video/audio fed to the player plus pages, images and scripts
- Tracker blocking (always on): blocks Google ad and analytics trackers (DoubleClick, Google Analytics, Tag Manager, ad services), YouTube's ad, telemetry and event-logging pings, and cookies from non-Google third parties. Rules live in `BlockRules.json` (Safari content-blocker format)
- Privacy menu → "Block Watch-Time Tracking": optional stricter mode that also blocks watch-time pings. This stops watch history and "resume where you left off", so it's off by default
- Links to other websites open in your normal browser
- Full-screen video works
- Always in dark mode, even if your Mac is set to light (if YouTube still looks light, set YouTube's own Appearance setting to "Use device theme" or "Dark theme")
- Quits when you close the window, so audio doesn't keep playing

## Files

- `TubeyApp.swift`: app entry point and menus
- `ContentView.swift`: window and toolbar
- `BrowserModel.swift`: the web view, navigation, link handling and picture in picture
- `WebView.swift`: connects the web view to SwiftUI
