import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hudController: HUDPanelController!
    private var slideDownController: SlideDownPanelController!
    private var menubarPresenter = MenubarPresenter()
    private var settingsWindow: NSWindow?
    private var settingsObserver: NSObjectProtocol?
    private var coordinatorObserver: NSObjectProtocol?
    private var menubarTickObserver: NSObjectProtocol?

    private var settings: DesklineSettings!
    private var coordinator: QuotaCoordinator!
    private var alertEngine: AlertEngine!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = DesklineSettings.shared
        coordinator = QuotaCoordinator()
        alertEngine = AlertEngine(settings: settings)
        alertEngine.requestAuthorization()

        NSApp.setActivationPolicy(.accessory)
        setupEditMenu()
        setupStatusItem()
        setupHUD()
        setupSlideDown()
        setupObservers()
        coordinator.start(settings: settings)
        syncChrome()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
        slideDownController.teardown()
        for observer in [settingsObserver, coordinatorObserver, menubarTickObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menubarPresenter.statusItem = statusItem

        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.load()
        button.image?.size = NSSize(width: 18, height: 18)
        button.title = " —"
        button.action = #selector(statusBarClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupHUD() {
        hudController = HUDPanelController(coordinator: coordinator, settings: settings)
        if settings.showsFloatingHUD {
            hudController.show()
        }
    }

    private func setupSlideDown() {
        slideDownController = SlideDownPanelController(coordinator: coordinator, settings: settings)
    }

    private func setupObservers() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .desklineSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncChrome()
        }

        coordinatorObserver = NotificationCenter.default.addObserver(
            forName: .desklineQuotaDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.alertEngine.evaluate(snapshots: self.coordinator.snapshots)
            self.menubarPresenter.update(coordinator: self.coordinator, settings: self.settings)
            if self.slideDownController.isVisible, let button = self.statusItem.button {
                self.slideDownController.refreshIfVisible(anchoredTo: button)
            }
        }

        menubarTickObserver = NotificationCenter.default.addObserver(
            forName: .desklineMenubarTick,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.menubarPresenter.update(coordinator: self.coordinator, settings: self.settings)
        }
    }

    private func syncChrome() {
        alertEngine.evaluate(snapshots: coordinator.snapshots)
        menubarPresenter.update(coordinator: coordinator, settings: settings)
        hudController.applySettings()
        if settings.showsFloatingHUD {
            hudController.show()
        } else {
            hudController.hide()
            slideDownController.close()
        }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isRightClick {
            buildContextMenu().popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height + 4),
                in: sender
            )
            return
        }

        switch settings.displayMode {
        case .deskline:
            slideDownController.toggle(anchoredTo: sender)
        case .detailedBar:
            hudController.resetPosition()
            hudController.show()
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        menu.addItem(
            withTitle: settings.hudVisible ? "Hide Floating Strip" : "Show Floating Strip",
            action: #selector(toggleFloatingHUD),
            keyEquivalent: "h"
        )
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Deskline", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettings() {
        slideDownController.close()
        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: SettingsView()
                .environmentObject(settings)
                .environmentObject(coordinator)
        )

        let window = NSWindow(contentViewController: hosting)
        window.title = "Deskline Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 680))
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleFloatingHUD() {
        settings.hudVisible.toggle()
        syncChrome()
    }

    @objc private func refreshNow() {
        Task { @MainActor in
            coordinator.refreshNow(enabled: settings.enabledProviderList)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let desklineSettingsDidChange = Notification.Name("desklineSettingsDidChange")
    static let desklineQuotaDidChange = Notification.Name("desklineQuotaDidChange")
    static let desklineMenubarTick = Notification.Name("desklineMenubarTick")
}
