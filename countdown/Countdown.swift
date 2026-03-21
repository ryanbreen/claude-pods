import Cocoa

class CountdownWindow: NSWindow {
    var countdown: Int
    let textField: NSTextField

    init(seconds: Int) {
        self.countdown = seconds

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = NSSize(width: 300, height: 300)
        let windowOrigin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        let windowFrame = NSRect(origin: windowOrigin, size: windowSize)

        textField = NSTextField(labelWithString: "\(seconds)")
        textField.font = NSFont.systemFont(ofSize: 160, weight: .bold)
        textField.textColor = NSColor.white
        textField.alignment = .center
        textField.frame = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)

        super.init(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = .floating
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: windowSize))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 30
        visualEffect.layer?.masksToBounds = true

        visualEffect.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
        ])

        self.contentView = visualEffect
    }

    func start() {
        self.orderFrontRegardless()
        tick()
    }

    func tick() {
        textField.stringValue = "\(countdown)"

        if countdown <= 0 {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.animator().alphaValue = 0
            }, completionHandler: {
                NSApplication.shared.terminate(nil)
            })
            return
        }

        countdown -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.tick()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: CountdownWindow?
    let seconds: Int

    init(seconds: Int) {
        self.seconds = seconds
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = CountdownWindow(seconds: seconds)
        window?.start()
    }
}

let seconds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 3 : 3
let delegate = AppDelegate(seconds: seconds)
let app = NSApplication.shared
app.delegate = delegate
app.run()
