import Foundation
import WebKit
import AppKit

// Generic web login window — one per provider, each with its own cookie store.
// Owns the NSWindow/WKWebView and retains them until explicitly closed.
@MainActor
final class WebAuthController: NSObject, WKUIDelegate, WKNavigationDelegate, NSWindowDelegate {
    struct Config {
        let providerID: AIProvider
        let title: String
        let startURL: URL
        let dataStore: WKWebsiteDataStore
        let loginCheck: @MainActor (WKWebView, URL) async -> Bool
        let authCookieCheck: (@MainActor (WKWebsiteDataStore) async -> Bool)?

        init(
            providerID: AIProvider,
            title: String,
            startURL: URL,
            dataStore: WKWebsiteDataStore,
            loginCheck: @escaping @MainActor (WKWebView, URL) async -> Bool,
            authCookieCheck: (@MainActor (WKWebsiteDataStore) async -> Bool)? = nil
        ) {
            self.providerID = providerID
            self.title = title
            self.startURL = startURL
            self.dataStore = dataStore
            self.loginCheck = loginCheck
            self.authCookieCheck = authCookieCheck
        }
    }

    private static var active: [AIProvider: WebAuthController] = [:]

    private var window: NSWindow?
    private var webView: WKWebView?
    private var statusLabel: NSTextField?
    private let config: Config
    private let onComplete: @MainActor () -> Void
    private var closing = false
    private var cookiePollTimer: Timer?

    static func show(_ config: Config, onComplete: @escaping @MainActor () -> Void) {
        if let existing = active[config.providerID] {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let ctrl = WebAuthController(config: config, onComplete: onComplete)
        active[config.providerID] = ctrl
        ctrl.openWindow()
    }

    private init(config: Config, onComplete: @escaping @MainActor () -> Void) {
        self.config = config
        self.onComplete = onComplete
        super.init()
    }

    private func openWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 760),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = config.title
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        w.level = .floating

        let wkConfig = WKWebViewConfiguration()
        wkConfig.websiteDataStore = config.dataStore
        wkConfig.preferences.javaScriptCanOpenWindowsAutomatically = true
        wkConfig.defaultWebpagePreferences.allowsContentJavaScript = true

        let status = NSTextField(labelWithString: "Loading sign-in page…")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byWordWrapping
        status.maximumNumberOfLines = 3
        status.translatesAutoresizingMaskIntoConstraints = false

        let wv = WKWebView(frame: .zero, configuration: wkConfig)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.uiDelegate = self
        wv.navigationDelegate = self
        wv.customUserAgent = safariUserAgent

        let container = NSView(frame: w.contentView!.bounds)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(wv)
        container.addSubview(status)
        w.contentView?.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
            container.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            container.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),

            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wv.topAnchor.constraint(equalTo: container.topAnchor),
            wv.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -6),

            status.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            status.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            status.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])

        wv.load(URLRequest(url: config.startURL))

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = w
        self.webView = wv
        self.statusLabel = status
        startCookiePolling()
    }

    private func startCookiePolling() {
        cookiePollTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.evaluateLoginSuccess(trigger: "cookie") }
        }
        t.tolerance = 0.4
        cookiePollTimer = t
    }

    private func stopCookiePolling() {
        cookiePollTimer?.invalidate()
        cookiePollTimer = nil
    }

    private func setStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    private func evaluateLoginSuccess(trigger: String) async {
        guard !closing, let wv = webView else { return }

        if let cookieCheck = config.authCookieCheck,
           await cookieCheck(config.dataStore) {
            await completeLogin(reason: "session cookie (\(trigger))")
            return
        }

        if let url = wv.url, await config.loginCheck(wv, url) {
            await completeLogin(reason: "URL (\(trigger))")
        }
    }

    private func completeLogin(reason: String) async {
        guard !closing else { return }
        closing = true
        stopCookiePolling()
        setStatus("Signed in — closing…")
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        window?.close()
    }

    // Handle window.open() popups (Google SSO uses these) by loading in same view
    nonisolated func webView(_ webView: WKWebView,
                             createWebViewWith configuration: WKWebViewConfiguration,
                             for navigationAction: WKNavigationAction,
                             windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            DispatchQueue.main.async { webView.load(URLRequest(url: url)) }
        }
        return nil
    }

    nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in self.setStatus("Loading sign-in page…") }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard !self.closing else { return }
            if let url = self.webView?.url {
                self.setStatus(self.statusForLoadedHost(url.host ?? "page"))
            }
            await self.evaluateLoginSuccess(trigger: "navigation")
        }
    }

    /// Google blocks OAuth inside embedded web views (blank "disallowed_useragent"
    /// page), so be honest when the flow lands there instead of saying "complete sign-in".
    private func statusForLoadedHost(_ host: String) -> String {
        if host.contains("accounts.google.com") || host.contains("google.com") {
            let base = "Google blocks app sign-in here (blank page). Try email/password sign-in instead of \"Continue with Google\""
            if config.providerID.supportsLocalQuota {
                return base + " — or just close this: \(config.providerID.displayName) usage still works from local files."
            }
            return base + "."
        }
        return "Loaded \(host) — complete sign-in if prompted."
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFail navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in self.reportLoadFailure(error) }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFailProvisionalNavigation navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in self.reportLoadFailure(error) }
    }

    private func reportLoadFailure(_ error: Error) {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return }
        setStatus(
            "Could not load the sign-in page (\(ns.localizedDescription)). "
            + "The site may block embedded browsers (Cloudflare). "
            + "Close this window — Claude Code quota still works via local estimate."
        )
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.stopCookiePolling()
            self.webView?.navigationDelegate = nil
            self.webView?.uiDelegate = nil
            self.webView = nil
            self.statusLabel = nil
            self.window = nil
            WebAuthController.active[self.config.providerID] = nil
            self.onComplete()
        }
    }
}
