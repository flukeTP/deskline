import AppKit
import SwiftUI

protocol HUDPanelDragging: AnyObject {
    func beginHUDDrag(with event: NSEvent)
    func continueHUDDrag(with event: NSEvent)
    func endHUDDrag(with event: NSEvent)
}

final class HUDPanel: NSPanel {
    weak var dragHandler: HUDPanelDragging?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragHandler?.beginHUDDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        dragHandler?.continueHUDDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        dragHandler?.endHUDDrag(with: event)
    }
}

final class HUDPanelController: NSObject, HUDPanelDragging {
    private let panel: HUDPanel
    private let hostingController: NSHostingController<AnyView>
    private let coordinator: QuotaCoordinator
    private let settings: DesklineSettings
    private var dragStartMouseScreen: NSPoint?
    private var dragStartPanelOrigin: NSPoint?

    init(coordinator: QuotaCoordinator, settings: DesklineSettings) {
        self.coordinator = coordinator
        self.settings = settings

        hostingController = NSHostingController(
            rootView: AnyView(
                HUDBarView()
                    .environmentObject(coordinator)
                    .environmentObject(settings)
            )
        )

        panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.dragHandler = nil
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        super.init()
        panel.dragHandler = self
        applySettings()
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func applySettings() {
        let draggable = settings.hudDraggable
        panel.ignoresMouseEvents = settings.clickThrough
        panel.dragHandler = draggable ? self : nil
        panel.alphaValue = 1.0
        hostingController.rootView = AnyView(
            HUDBarView()
                .environmentObject(coordinator)
                .environmentObject(settings)
        )
        hostingController.view.layoutSubtreeIfNeeded()
        panel.setContentSize(measuredSize())
        reposition()
        if settings.hudVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func resetPosition() {
        settings.resetHUDPosition()
        reposition()
    }

    func beginHUDDrag(with event: NSEvent) {
        guard settings.hudDraggable else { return }
        dragStartMouseScreen = NSEvent.mouseLocation
        dragStartPanelOrigin = panel.frame.origin
    }

    func continueHUDDrag(with event: NSEvent) {
        guard settings.hudDraggable,
              let startMouse = dragStartMouseScreen,
              let startOrigin = dragStartPanelOrigin else { return }

        let current = NSEvent.mouseLocation
        let dx = current.x - startMouse.x
        let dy = current.y - startMouse.y
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
        clampToVisibleScreen(size: size)
    }

    func endHUDDrag(with event: NSEvent) {
        guard settings.hudDraggable else { return }
        settings.saveHUDOrigin(panel.frame.origin)
        dragStartMouseScreen = nil
        dragStartPanelOrigin = nil
    }

    private func measuredSize() -> NSSize {
        hostingController.view.layoutSubtreeIfNeeded()
        let size = hostingController.view.fittingSize
        return NSSize(width: max(280, ceil(size.width)), height: max(40, ceil(size.height)))
    }

    private func reposition() {
        let size = measuredSize()
        if settings.hudHasCustomPosition, let x = settings.hudCustomX, let y = settings.hudCustomY {
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
            clampToVisibleScreen(size: size)
            if settings.hudHasCustomPosition {
                settings.saveHUDOrigin(panel.frame.origin)
            }
            return
        }

        guard let screen = screenForPanel() else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 12
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func clampToVisibleScreen(size: NSSize) {
        guard let screen = screenContaining(panel.frame) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var origin = panel.frame.origin
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(origin)
    }

    private func screenForPanel() -> NSScreen? {
        if settings.hudHasCustomPosition, let x = settings.hudCustomX, let y = settings.hudCustomY {
            return screenContaining(NSRect(x: x, y: y, width: 1, height: 1))
        }
        return NSScreen.main
    }

    private func screenContaining(_ rect: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main
    }
}
