/* bigclock (Mac only)
 Description: Semi-transparent clock that sits in the bottom right of the screen.
              Becomes more opaque on mouse-over. Doesn't interfere with anything
              underneath. Also adds a little menubar icon to close the window.
 Build: swift build -c release

 The MIT License (MIT)

 Copyright (c) 2022 George Watson

 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge,
 publish, distribute, sublicense, and/or sell copies of the Software,
 and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

import Cocoa
import ArgumentParser

enum FadeState {
    case fadeIn, fadeOut, nothing
}

var fadeState: FadeState = .nothing

class AppView: NSView {
    var minOpacity: Double
    var maxOpacity: Double
    var currentOpacity: Double

    init(frame: NSRect, minOpacity: Double, maxOpacity: Double) {
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        self.currentOpacity = minOpacity
        super.init(frame: frame)
        addTrackingRect(visibleRect, owner: self, userData: nil, assumeInside: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ frame: NSRect) {
        let path = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
        NSColor(red: 0, green: 0, blue: 0, alpha: currentOpacity).set()
        path.fill()
    }

    override func mouseEntered(with event: NSEvent) {
        fadeState = .fadeIn
    }

    override func mouseExited(with event: NSEvent) {
        fadeState = .fadeOut
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let config: ClockConfig
    var window: NSWindow!
    var view: AppView!
    var label: NSTextField!
    var timer: Timer!
    var fadeTimer: Timer!
    var statusItem: NSStatusItem!

    init(config: ClockConfig) {
        self.config = config
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: config.width, height: config.height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.title = ProcessInfo.processInfo.processName

        let screen = NSScreen.main!
        let visibleFrame = screen.visibleFrame
        window.setFrameOrigin(NSPoint(
            x: visibleFrame.origin.x + visibleFrame.size.width - config.width - config.margin,
            y: visibleFrame.origin.y + config.margin
        ))
        window.isOpaque = false
        window.isExcludedFromWindowsMenu = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.makeKeyAndOrderFront(self)
        window.level = .floating
        window.canHide = false
        window.collectionBehavior = .canJoinAllSpaces

        view = AppView(
            frame: NSRect(x: 0, y: 0, width: config.width, height: config.height),
            minOpacity: config.minOpacity,
            maxOpacity: config.maxOpacity
        )

        label = NSTextField(frame: NSRect(x: 0, y: 0, width: config.width, height: config.height - 3))
        label.stringValue = ""
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: config.fontSize)
        label.textColor = NSColor.white.withAlphaComponent(0.5)
        label.cell?.backgroundStyle = .raised

        window.contentView = view
        view.addSubview(label)

        NSApp.setActivationPolicy(.accessory)

        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: .modalPanel)

        fadeTimer = Timer.scheduledTimer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(fadeUpdate), userInfo: nil, repeats: true)
        RunLoop.current.add(fadeTimer, forMode: .modalPanel)

        updateClock()
    }

    @objc func updateClock() {
        autoreleasepool {
            let fmt = DateFormatter()
            fmt.dateFormat = config.timeFormat
            label.stringValue = fmt.string(from: Date())
            view.setNeedsDisplay(view.bounds)
        }
    }

    func updateFade(_ v: Double) {
        view.currentOpacity += v / 10.0
        label.textColor = NSColor.white.withAlphaComponent(0.25 + view.currentOpacity)
        view.setNeedsDisplay(view.bounds)
    }

    @objc func fadeUpdate() {
        switch fadeState {
        case .fadeIn:
            if view.currentOpacity < config.maxOpacity {
                updateFade(timer.fireDate.timeIntervalSince(Date()))
            } else {
                view.currentOpacity = config.maxOpacity
                fadeState = .nothing
            }
        case .fadeOut:
            if view.currentOpacity > config.minOpacity {
                updateFade(-timer.fireDate.timeIntervalSince(Date()))
            } else {
                view.currentOpacity = config.minOpacity
                fadeState = .nothing
            }
        case .nothing:
            break
        }
    }
}

struct ClockConfig {
    var maxOpacity: Double
    var minOpacity: Double
    var fontSize: CGFloat
    var timeFormat: String
    var width: CGFloat
    var height: CGFloat
    var margin: CGFloat
}

@main
struct BigClock: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bigclock",
        abstract: "Semi-transparent floating clock for macOS"
    )

    @Option(name: .long, help: "Maximum opacity when mouse is over the clock (0.0–1.0)")
    var maxOpacity: Double = 0.75

    @Option(name: .long, help: "Minimum opacity when mouse is away (0.0–1.0)")
    var minOpacity: Double = 0.30

    @Option(name: .long, help: "Font size for the clock digits")
    var fontSize: Double = 72

    @Option(name: .long, help: "Date format string (e.g. hh:mm:ss or HH:mm)")
    var timeFormat: String = "hh:mm:ss"

    @Option(name: .long, help: "Window width in points")
    var width: Double = 310

    @Option(name: .long, help: "Window height in points")
    var height: Double = 95

    @Option(name: .long, help: "Margin from screen edges in points")
    var margin: Double = 20

    mutating func run() throws {
        let config = ClockConfig(
            maxOpacity: maxOpacity,
            minOpacity: minOpacity,
            fontSize: CGFloat(fontSize),
            timeFormat: timeFormat,
            width: CGFloat(width),
            height: CGFloat(height),
            margin: CGFloat(margin)
        )

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate(config: config)
        app.delegate = delegate
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
