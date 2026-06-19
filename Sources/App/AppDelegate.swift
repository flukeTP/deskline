import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hudController: HUDPanelController!
    private var settingsWindow: NSWindow?
    private var settingsObserver: NSObjectProtocol?

    private var settings: DesklineSettings!
    private var coordinator: QuotaCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = DesklineSettings.shared
        coordinator = QuotaCoordinator()

        NSApp.setActivationPolicy(.accessory)
        setupEditMenu()
        setupStatusItem()
        setupHUD()
        setupSettingsObserver()
        coordinator.start(settings: settings)
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "Deskline")
            button.image?.size = NSSize(width: 14, height: 14)
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: settings.hudVisible ? "Hide HUD" : "Show HUD", action: #selector(toggleHUD), keyEquivalent: "h")
        menu.addItem(withTitle: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Deskline", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func setupHUD() {
        hudController = HUDPanelController(coordinator: coordinator, settings: settings)
        if settings.hudVisible {
            hudController.show()
        }
    }

    private func setupSettingsObserver() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .desklineSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hudController.applySettings()
            self?.syncHUDMenuTitle()
        }
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
        window.setContentSize(NSSize(width: 380, height: 460))
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleHUD() {
        settings.hudVisible.toggle()
        hudController.applySettings()
        syncHUDMenuTitle()
    }

    @objc private func refreshNow() {
        coordinator.refreshNow(enabled: settings.enabledProviderList)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func syncHUDMenuTitle() {
        guard let menu = statusItem.menu, menu.items.count > 2 else { return }
        menu.items[2].title = settings.hudVisible ? "Hide HUD" : "Show HUD"
    }
}

extension Notification.Name {
    static let desklineSettingsDidChange = Notification.Name("desklineSettingsDidChange")
}
