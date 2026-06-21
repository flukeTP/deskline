import AppKit
import Combine
import SwiftUI

final class HUDPanelController: NSObject {
    private let panel: NSPanel
    private let hostingView: DraggableHostingView
    private let coordinator: QuotaCoordinator
    private let settings: DesklineSettings
    private var coordinatorObserver: AnyCancellable?
    private var isUserDragging = false

    init(coordinator: QuotaCoordinator, settings: DesklineSettings) {
        self.coordinator = coordinator
        self.settings = settings

        hostingView = DraggableHostingView(rootView: AnyView(EmptyView()))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true

        super.init()

        hostingView.onDragBegan = { [weak self] in
            self?.isUserDragging = true
        }
        hostingView.onDragEnded = { [weak self] in
            self?.handleDragEnded()
        }

        coordinatorObserver = coordinator.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.resizeToFitIfNeeded() }
        }
        rebuildRootView()
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
        hostingView.isDraggable = draggable
        panel.isMovableByWindowBackground = draggable
        panel.alphaValue = 1.0
        rebuildRootView()
        hostingView.layoutSubtreeIfNeeded()
        panel.setContentSize(measuredSize())
        reposition()
        if settings.showsFloatingHUD {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func resetPosition() {
        settings.resetHUDPosition()
        reposition()
    }

    func resizeToFitIfNeeded() {
        guard settings.showsFloatingHUD, !isUserDragging else { return }
        hostingView.layoutSubtreeIfNeeded()
        let size = measuredSize()
        let origin = panel.frame.origin
        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height), display: true)
        clampToVisibleScreen(size: size)
    }

    private func handleDragEnded() {
        isUserDragging = false
        guard settings.hudDraggable else { return }
        settings.saveHUDOrigin(panel.frame.origin)
        clampToVisibleScreen(size: panel.frame.size)
        if settings.hudHasCustomPosition {
            settings.saveHUDOrigin(panel.frame.origin)
        }
    }

    private func rebuildRootView() {
        switch settings.displayMode {
        case .deskline:
            hostingView.rootView = AnyView(
                DesklineStripView(density: .compact, showTopAccent: true)
                    .environmentObject(coordinator)
                    .environmentObject(settings)
            )
        case .detailedBar:
            hostingView.rootView = AnyView(
                HUDBarView(layout: .horizontal, style: .floating)
                    .environmentObject(coordinator)
                    .environmentObject(settings)
            )
        }
    }

    private func measuredSize() -> NSSize {
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        let minHeight: CGFloat = settings.displayMode == .deskline ? 28 : 36
        return NSSize(width: max(180, ceil(size.width)), height: max(minHeight, ceil(size.height)))
    }

    private func reposition() {
        let size = measuredSize()
        if settings.hudHasCustomPosition, let x = settings.hudCustomX, let y = settings.hudCustomY {
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
            clampToVisibleScreen(size: size)
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
