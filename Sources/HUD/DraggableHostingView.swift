import AppKit
import SwiftUI

/// NSHostingView that lets the user drag the panel by clicking anywhere on the HUD.
final class DraggableHostingView: NSHostingView<AnyView> {
    var isDraggable: Bool = true
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard isDraggable, let window else {
            super.mouseDown(with: event)
            return
        }
        // performDrag takes over event tracking and moves the window until mouse-up,
        // bypassing the SwiftUI subview hit-testing that blocks mouseDownCanMoveWindow.
        onDragBegan?()
        window.performDrag(with: event)
        onDragEnded?()
    }

    override var mouseDownCanMoveWindow: Bool { isDraggable }
}
