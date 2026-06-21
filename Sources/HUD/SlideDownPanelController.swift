import AppKit
import SwiftUI

final class SlideDownPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class SlideDownPanelController {
    private let panel: SlideDownPanel
    private let hostingController: NSHostingController<AnyView>
    private let coordinator: QuotaCoordinator
    private let settings: DesklineSettings
    private var eventMonitor: Any?
    private weak var anchorButton: NSStatusBarButton?
    private var ignoreOutsideClicksUntil: Date = .distantPast

    init(coordinator: QuotaCoordinator, settings: DesklineSettings) {
        self.coordinator = coordinator
        self.settings = settings
        hostingController = NSHostingController(rootView: AnyView(EmptyView()))
        panel = SlideDownPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                if Date() < self.ignoreOutsideClicksUntil { return }
                if self.isClickInsidePanelOrAnchor(event) { return }
                self.close()
            }
        }
    }

    func teardown() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(anchoredTo button: NSStatusBarButton) {
        anchorButton = button
        if panel.isVisible { close() } else { open(anchoredTo: button) }
    }

    func close() {
        let wasVisible = panel.isVisible
        panel.orderOut(nil)
        // You've seen the detail — clear flip highlights for next time.
        if wasVisible { coordinator.acknowledgeWatchlist() }
    }

    func refreshIfVisible(anchoredTo button: NSStatusBarButton) {
        guard panel.isVisible else { return }
        anchorButton = button
        layout(anchoredTo: button)
    }

    private func open(anchoredTo button: NSStatusBarButton) {
        anchorButton = button
        ignoreOutsideClicksUntil = Date().addingTimeInterval(0.2)
        layout(anchoredTo: button)
        panel.orderFrontRegardless()
    }

    private func layout(anchoredTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }

        hostingController.rootView = AnyView(
            DesklineStripView(density: .expanded, showTopAccent: true)
                .environmentObject(coordinator)
                .environmentObject(settings)
        )
        hostingController.view.layoutSubtreeIfNeeded()
        let size = hostingController.view.fittingSize
        let width = max(280, ceil(size.width))
        let height = max(40, ceil(size.height))

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let gap: CGFloat = 2
        let x = min(max(buttonRect.midX - width / 2, screen.minX + 8), screen.maxX - width - 8)
        let y = buttonRect.minY - height - gap

        panel.setContentSize(NSSize(width: width, height: height))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func isClickInsidePanelOrAnchor(_ event: NSEvent) -> Bool {
        let point = NSEvent.mouseLocation
        if panel.frame.contains(point) { return true }
        guard let button = anchorButton, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point)
    }
}
