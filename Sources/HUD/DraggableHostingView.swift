import AppKit
import SwiftUI

/// NSHostingView that lets the user drag the panel by clicking anywhere on the HUD.
final class DraggableHostingView: NSHostingView<AnyView> {
    var isDraggable: Bool = true
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        window?.isMovableByWindowBackground = isDraggable
        if isDraggable { onDragBegan?() }
        super.mouseDown(with: event)
    }

    override var mouseDownCanMoveWindow: Bool { isDraggable }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if isDraggable {
            onDragEnded?()
        }
    }
}
