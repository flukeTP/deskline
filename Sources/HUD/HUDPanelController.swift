import AppKit
import SwiftUI

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class HUDPanelController {
    private let panel: HUDPanel
    private let hostingController: NSHostingController<AnyView>
    private let coordinator: QuotaCoordinator
    private let settings: DesklineSettings

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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

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
        panel.ignoresMouseEvents = settings.clickThrough
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

    private func measuredSize() -> NSSize {
        hostingController.view.layoutSubtreeIfNeeded()
        let size = hostingController.view.fittingSize
        return NSSize(width: max(280, ceil(size.width)), height: max(36, ceil(size.height)))
    }

    private func reposition() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = measuredSize()
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 12
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
