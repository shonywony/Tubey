import AppKit
import SwiftUI

/// The Features and Add-ons dropdowns, built as native macOS menus so each item can show an icon,
/// a grey description line underneath, and a tooltip.
@MainActor
enum SpecialFeaturesMenu {
    /// The Features dropdown: browsing, clean view and playback.
    static func show(for browser: BrowserModel, from anchor: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.showsStateColumn = false

        menu.addItem(.sectionHeader(title: "Browsing"))
        menu.addItem(toggle("Focus Mode", "Opens Tubey on your Subscriptions page", "scope",
                            browser.focusMode) { browser.focusMode = $0 })

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Clean View"))
        menu.addItem(toggle("Hide Recommendations", "Hides suggested videos; videos open in Theater mode",
                            "rectangle.grid.2x2", browser.hideRecommendations) { browser.hideRecommendations = $0 })
        menu.addItem(toggle("Hide Shorts", "Removes Shorts everywhere on YouTube", "rectangle.portrait.slash",
                            browser.hideShorts) { browser.hideShorts = $0 })
        menu.addItem(toggle("Hide Playables", "Removes YouTube's mini-games from Home and the sidebar",
                            "gamecontroller", browser.hidePlayables) { browser.hidePlayables = $0 })
        menu.addItem(toggle("Hide Comments", "Hides the comments under videos", "text.bubble",
                            browser.hideComments) { browser.hideComments = $0 })
        menu.addItem(toggle("Hide End Cards", "Hides pop-up cards and end-of-video suggestions",
                            "rectangle.on.rectangle.slash", browser.hideEndCards) { browser.hideEndCards = $0 })
        menu.addItem(toggle("Hide Live Chat", "Hides the chat beside live streams", "bubble.left.and.bubble.right",
                            browser.hideLiveChat) { browser.hideLiveChat = $0 })
        menu.addItem(toggle("Hide Subscriptions Header", "Removes the “Latest” bar so videos sit higher",
                            "rectangle.topthird.inset.filled", browser.hideFeedHeader) { browser.hideFeedHeader = $0 })

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Playback"))
        var introsRow: ToggleRowView?
        menu.addItem(toggle("Skip Sponsors", "Jumps past sponsor reads and plugs (SponsorBlock)", "forward.end",
                            browser.skipSponsors) {
            browser.skipSponsors = $0
            introsRow?.isActive = $0
        })
        menu.addItem(toggle("Also Skip Intros & Outros", "Skips channel intros and end segments too", "forward",
                            browser.skipIntrosAndOutros, enabled: browser.skipSponsors) {
            browser.skipIntrosAndOutros = $0
        })
        introsRow = menu.items.last?.view as? ToggleRowView
        menu.addItem(toggle("Auto-Dismiss \u{201C}Still Watching?\u{201D}",
                            "Keeps long sessions playing without the pause prompt", "play.circle",
                            browser.autoDismissStillWatching) { browser.autoDismissStillWatching = $0 })
        menu.addItem(choice("Default Speed", "Starting speed for every video", "gauge.with.dots.needle.67percent",
                            options: PlaybackSpeed.allCases.map { speed in (speed.title, speed == browser.defaultSpeed, { browser.defaultSpeed = speed }) }))
        menu.addItem(choice("Video Quality", "Starting quality for every video", "sparkles.tv",
                            options: VideoQuality.allCases.map { quality in (quality.title, quality == browser.videoQuality, { browser.videoQuality = quality }) }))

        present(menu, from: anchor)
    }

    /// The Add-ons dropdown: dislikes, menu bar player, bandwidth monitor, privacy and appearance.
    static func showAddOns(for browser: BrowserModel, from anchor: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.showsStateColumn = false

        menu.addItem(.sectionHeader(title: "Add-ons"))
        menu.addItem(toggle("Show Dislikes", "Dislike counts from Return YouTube Dislike", "hand.thumbsdown",
                            browser.showDislikes) { browser.showDislikes = $0 })
        menu.addItem(toggle("DeArrow", "Swaps clickbait titles and thumbnails for honest ones",
                            "arrow.uturn.down.square", browser.showDeArrow) { browser.showDeArrow = $0 })
        menu.addItem(toggle("Menu Bar Player", "A mini player in the menu bar at the top of the screen",
                            "menubar.rectangle", browser.showMenuBarPlayer) { browser.showMenuBarPlayer = $0 })
        menu.addItem(toggle("Show Bandwidth Monitor", "Live data use in the bottom-right corner", "arrow.down.circle",
                            browser.showBandwidth) { browser.showBandwidth = $0 })

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Privacy"))
        menu.addItem(toggle("Block Ad & Analytics Trackers",
                            "Blocks DoubleClick, Google Analytics and tracking cookies",
                            "hand.raised", browser.blockTrackers) { browser.blockTrackers = $0 })
        menu.addItem(toggle("Block Watch-Time Tracking", "More private, but turns off watch history", "eye.slash",
                            browser.blockWatchHistory) { browser.blockWatchHistory = $0 })

        present(menu, from: anchor)
    }

    private static func present(_ menu: NSMenu, from anchor: NSView?) {
        // Drop the menu down just below the button (or at the pointer, if the button's position isn't known).
        if let anchor, anchor.window != nil {
            // Line the menu's right edge up with the button's, so it stays inside the window.
            let x = anchor.bounds.width - menu.size.width
            let y = anchor.isFlipped ? anchor.bounds.height + 6 : -6
            menu.popUp(positioning: nil, at: NSPoint(x: x, y: y), in: anchor)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    /// An on/off row with an icon, title, description line and a switch on the right.
    /// The menu stays open while you flip switches.
    private static func toggle(
        _ title: String, _ description: String, _ symbol: String, _ isOn: Bool,
        enabled: Bool = true, action: @escaping (Bool) -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = ToggleRowView(title: title, description: description, symbol: symbol,
                                  isOn: isOn, isActive: enabled, onChange: action)
        return item
    }

    /// An item with a submenu of choices (speed, quality, appearance).
    private static func choice(
        _ title: String, _ description: String, _ symbol: String,
        options: [(String, Bool, () -> Void)]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (name, selected, action) in options {
            let option = ActionMenuItem(title: name, action: action)
            option.state = selected ? .on : .off
            submenu.addItem(option)
        }
        item.submenu = submenu
        decorate(item, description, symbol)
        return item
    }

    /// Width of the icon column, so titles and descriptions line up on every row.
    private static let iconColumn: CGFloat = 24

    private static func decorate(_ item: NSMenuItem, _ description: String, _ symbol: String) {
        // Drawn as one rich title: icon, name, and a smaller grey description on the line below.
        // (macOS drops item icons from this menu, ignores rich titles when a subtitle is set,
        // and ignores indents, so the spacing is built from fixed-width images.)
        let titleFont = NSFont.menuFont(ofSize: 0)
        let text = NSMutableAttributedString()

        let config = NSImage.SymbolConfiguration(pointSize: titleFont.pointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
        if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: -2.5, width: icon.size.width, height: icon.size.height)
            text.append(NSAttributedString(attachment: attachment))
            // Pad every icon out to the same width so the titles line up.
            text.append(spacer(width: max(2, iconColumn - icon.size.width)))
        } else {
            text.append(spacer(width: iconColumn))
        }
        text.append(NSAttributedString(string: item.title, attributes: [.font: titleFont]))

        let smallFont = NSFont.systemFont(ofSize: titleFont.pointSize - 2)
        text.append(NSAttributedString(string: "\n", attributes: [.font: smallFont]))
        text.append(spacer(width: iconColumn))
        text.append(NSAttributedString(string: description, attributes: [
            .font: smallFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        item.attributedTitle = text
        item.toolTip = description
    }

    /// An invisible gap of an exact width (menus ignore indents and tab stops).
    private static func spacer(width: CGFloat) -> NSAttributedString {
        let image = NSImage(size: NSSize(width: width, height: 1), flipped: false) { _ in true }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: width, height: 1)
        return NSAttributedString(attachment: attachment)
    }
}

/// A Features row: icon, title and grey description on the left, an on/off switch on the right.
/// Clicking anywhere on the row flips the switch.
final class ToggleRowView: NSView {
    private let toggle = NSSwitch()
    private let titleLabel: NSTextField
    private let onChange: (Bool) -> Void

    /// Greys the row out (used for "Also Skip Intros & Outros" when Skip Sponsors is off).
    var isActive: Bool {
        didSet { applyActive() }
    }

    init(title: String, description: String, symbol: String, isOn: Bool, isActive: Bool,
         onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        self.isActive = isActive
        let menuFont = NSFont.menuFont(ofSize: 0)
        titleLabel = NSTextField(labelWithString: title)
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 46))
        toolTip = description

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: menuFont.pointSize + 1, weight: .regular)
        icon.contentTintColor = .labelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true

        titleLabel.font = menuFont
        let detail = NSTextField(labelWithString: description)
        detail.font = .systemFont(ofSize: menuFont.pointSize - 2)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail

        let texts = NSStackView(views: [titleLabel, detail])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1
        texts.setContentHuggingPriority(.defaultLow, for: .horizontal)

        toggle.controlSize = .small
        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(switchFlipped)
        toggle.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [icon, texts])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        addSubview(toggle)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            // Switch pinned to the right edge, so every switch lines up.
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
        ])
        applyActive()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func applyActive() {
        toggle.isEnabled = isActive
        titleLabel.textColor = isActive ? .labelColor : .disabledControlTextColor
        alphaValue = isActive ? 1 : 0.55
    }

    @objc private func switchFlipped() {
        onChange(toggle.state == .on)
    }

    // Clicking the row (not just the switch) flips it too.
    override func mouseUp(with event: NSEvent) {
        guard isActive else { return }
        toggle.state = toggle.state == .on ? .off : .on
        switchFlipped()
    }
}

/// A menu item that runs a closure when chosen.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() { handler() }
}

/// Remembers the toolbar button's position so the menu can drop down from it.
final class MenuAnchorBox {
    weak var view: NSView?
}

struct MenuAnchor: NSViewRepresentable {
    let box: MenuAnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        box.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { box.view = nsView }
}
