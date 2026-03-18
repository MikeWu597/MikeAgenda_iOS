import SwiftUI
import WebKit
import UniformTypeIdentifiers
import ActivityKit

struct MikeAgendaWebView: UIViewRepresentable {
    let profile: ConnectionProfile
    var onProfileChanged: (() -> Void)?
    var onColorModeChanged: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(profile: profile, onProfileChanged: onProfileChanged, onColorModeChanged: onColorModeChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: Coordinator.cookieHandlerName)
        userContentController.add(context.coordinator, name: Coordinator.configHandlerName)
        userContentController.add(context.coordinator, name: Coordinator.colorModeHandlerName)
        userContentController.addUserScript(
            WKUserScript(
                source: context.coordinator.cookieBootstrapScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        userContentController.addUserScript(
            WKUserScript(
                source: context.coordinator.typographyBootstrapScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        userContentController.addUserScript(
            WKUserScript(
                source: context.coordinator.profileInjectionScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.setURLSchemeHandler(context.coordinator.schemeHandler, forURLScheme: LocalSiteSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.delegate = context.coordinator
        webView.scrollView.isMultipleTouchEnabled = false

        context.coordinator.attach(webView: webView)
        context.coordinator.loadEntryPage()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(profile: profile)
    }
}

extension MikeAgendaWebView {
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIScrollViewDelegate {
        static let cookieHandlerName = "mikeAgendaCookie"
        static let configHandlerName = "mikeAgendaConfig"
        static let colorModeHandlerName = "mikeAgendaColorMode"

        private(set) var profile: ConnectionProfile
        let schemeHandler: LocalSiteSchemeHandler
        private weak var webView: WKWebView?
        private var loadedToken: String?
        private var onProfileChanged: (() -> Void)?
        private var onColorModeChanged: ((String) -> Void)?
        private var courseTimer: Timer?

        init(profile: ConnectionProfile, onProfileChanged: (() -> Void)?, onColorModeChanged: ((String) -> Void)?) {
            self.profile = profile
            self.onProfileChanged = onProfileChanged
            self.onColorModeChanged = onColorModeChanged
            self.schemeHandler = LocalSiteSchemeHandler(profile: profile)
        }

        var cookieBootstrapScript: String {
            let initialCookieString = ConnectionProfileStore.loadWebCookies().jsEscapedLiteral
            return """
            (() => {
                const readWindowNameCookies = () => {
                    const rawValue = String(window.name || '');
                    const prefix = '__mikeagenda_cookies=';
                    return rawValue.startsWith(prefix) ? rawValue.slice(prefix.length) : '';
                };

                const initialCookieString = (() => {
                    try {
                        return localStorage.getItem('__mikeagenda_cookies') || readWindowNameCookies() || \(initialCookieString);
                    } catch (error) {
                        return readWindowNameCookies() || \(initialCookieString);
                    }
                })();
                const cookieMap = {};

                const parseCookieString = (rawValue) => {
                    Object.keys(cookieMap).forEach((key) => delete cookieMap[key]);
                    String(rawValue || '')
                        .split(';')
                        .map((part) => part.trim())
                        .filter(Boolean)
                        .forEach((entry) => {
                            const separator = entry.indexOf('=');
                            if (separator <= 0) {
                                return;
                            }
                            const name = entry.slice(0, separator).trim();
                            const value = entry.slice(separator + 1).trim();
                            cookieMap[name] = value;
                        });
                };

                const serializedCookies = () => Object.entries(cookieMap)
                    .map(([name, value]) => `${name}=${value}`)
                    .join('; ');

                const syncCookies = () => {
                    const value = serializedCookies();

                    try {
                        localStorage.setItem('__mikeagenda_cookies', value);
                    } catch (error) {
                    }

                    window.name = `__mikeagenda_cookies=${value}`;

                    window.webkit.messageHandlers.\(Self.cookieHandlerName).postMessage({
                        value: value
                    });
                };

                const applyCookieMutation = (input) => {
                    const parts = String(input || '')
                        .split(';')
                        .map((part) => part.trim())
                        .filter(Boolean);

                    if (!parts.length) {
                        return;
                    }

                    const firstPart = parts[0];
                    const separator = firstPart.indexOf('=');
                    if (separator <= 0) {
                        return;
                    }

                    const name = firstPart.slice(0, separator).trim();
                    const value = firstPart.slice(separator + 1).trim();

                    let shouldDelete = value.length === 0;

                    parts.slice(1).forEach((attribute) => {
                        const [attributeName, attributeValue = ''] = attribute.split('=');
                        const normalizedName = attributeName.toLowerCase();

                        if (normalizedName === 'expires') {
                            const expiresAt = new Date(attributeValue);
                            if (!Number.isNaN(expiresAt.getTime()) && expiresAt.getTime() <= Date.now()) {
                                shouldDelete = true;
                            }
                        }

                        if (normalizedName === 'max-age') {
                            const maxAge = Number(attributeValue);
                            if (!Number.isNaN(maxAge) && maxAge <= 0) {
                                shouldDelete = true;
                            }
                        }
                    });

                    if (shouldDelete) {
                        delete cookieMap[name];
                    } else {
                        cookieMap[name] = value;
                    }

                    syncCookies();
                };

                parseCookieString(initialCookieString);
                syncCookies();

                const cookieDescriptor = {
                    configurable: true,
                    enumerable: true,
                    get() {
                        return serializedCookies();
                    },
                    set(value) {
                        applyCookieMutation(value);
                    }
                };

                try {
                    Object.defineProperty(Document.prototype, 'cookie', cookieDescriptor);
                } catch (error) {
                    try {
                        Object.defineProperty(document, 'cookie', cookieDescriptor);
                    } catch (innerError) {
                    }
                }
            })();
            """
        }

        var typographyBootstrapScript: String {
            """
            (() => {
                const fontCSS = `
                    html, body, button, input, textarea, select, option,
                    .el-button, .el-input__inner, .el-input__wrapper, .el-textarea__inner,
                    .el-select, .el-dropdown-menu, .el-dialog, .el-message-box {
                        font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif !important;
                    }
                `;

                const darkCSS = `
                    /* Body & page background */
                    html.dark body { background: #0a0a0a !important; color: #E5EAF3 !important; }
                    html.dark #app { color: #E5EAF3; }

                    /* Page headers & card backgrounds */
                    html.dark .page-header,
                    html.dark .page-container { background: #141414 !important; box-shadow: 0 1px 4px rgba(0,0,0,0.3) !important; }
                    html.dark .el-card { background: #141414 !important; border-color: #414243 !important; }
                    html.dark .el-card__header { border-bottom-color: #414243 !important; }

                    /* Titles & text */
                    html.dark .page-title { color: #E5EAF3 !important; }
                    html.dark .muted, html.dark .meta, html.dark .hint { color: #8D9095 !important; }

                    /* Login page */
                    html.dark .login-card { background: #141414 !important; box-shadow: 0 2px 12px rgba(0,0,0,0.4) !important; }
                    html.dark .login-title { color: #E5EAF3 !important; }

                    /* Item cards */
                    html.dark .item-card { background: #1d1d1d !important; border-color: #414243 !important; }
                    html.dark .item-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.4) !important; }
                    html.dark .item-title { color: #E5EAF3 !important; }
                    html.dark .item-description { color: #A3A6AD !important; }
                    html.dark .item-meta { color: #8D9095 !important; }

                    /* Dash: top header, section cards, loading */
                    html.dark .top-header { background: #141414 !important; box-shadow: 0 1px 4px rgba(0,0,0,0.3) !important; }
                    html.dark .header-title, html.dark .section-title { color: #E5EAF3 !important; }
                    html.dark .loading-box { background: rgba(20, 20, 20, 0.92) !important; }
                    html.dark .loading-text { color: #A3A6AD !important; }
                    html.dark #app-loading { background: #0a0a0a !important; }
                    html.dark .section-card { background: #141414 !important; box-shadow: 0 1px 4px rgba(0,0,0,0.3) !important; }
                    html.dark .empty-state { color: #8D9095 !important; }

                    /* Checklist */
                    html.dark .item-card.checked { background: rgba(64,158,255,0.1) !important; }
                    html.dark .item-name.checked { color: #8D9095 !important; }

                    /* Sortable / drag items */
                    html.dark .sortable-item { background: #1d1d1d !important; border-color: #414243 !important; }
                    html.dark .drag-handle { color: #8D9095 !important; }

                    /* Process rows (item_done) */
                    html.dark .process-row { background: #1d1d1d !important; border-color: #414243 !important; }

                    /* Courses schedule */
                    html.dark .schedule { color: #E5EAF3 !important; }
                    html.dark .schedule-header { background: #141414 !important; border-bottom-color: #414243 !important; }
                    html.dark .head-cell { background: #1a1a1a !important; border-right-color: #414243 !important; }
                    html.dark .time-col { background: #141414 !important; border-right-color: #414243 !important; }
                    html.dark .time-head { background: #141414 !important; }
                    html.dark .time-cell { color: #A3A6AD !important; border-bottom-color: #414243 !important; }
                    html.dark .time-label { background: rgba(20,20,20,0.85) !important; color: #A3A6AD !important; }
                    html.dark .day-col { background-color: #141414 !important; border-right-color: #414243 !important; }
                    html.dark .canvas-wrap { border-color: #414243 !important; }

                    /* Project detail calendar */
                    html.dark .month-card { border-color: #414243 !important; }
                    html.dark .month-header { background-color: rgba(64,158,255,0.15) !important; color: #66b3ff !important; }
                    html.dark .calendar-day.empty,
                    html.dark .calendar-day.future-day { background-color: #1a1a1a !important; }
                    html.dark .calendar-day.future-day { color: #606266 !important; }
                    html.dark .calendar-day.no-activity { background-color: #252525 !important; }
                    html.dark .activity-level-0 { background-color: rgba(64,158,255,0.08) !important; }

                    /* Farm tool */
                    html.dark .image-card { background: #1d1d1d !important; box-shadow: 0 1px 4px rgba(0,0,0,0.3) !important; }
                    html.dark .info-row { color: #A3A6AD !important; }
                    html.dark .info-label { color: #8D9095 !important; }

                    /* Element Plus overrides for dark */
                    html.dark .el-divider__text { background-color: #141414 !important; color: #A3A6AD !important; }
                    html.dark .el-table { background-color: #141414 !important; color: #E5EAF3 !important; }
                    html.dark .el-table th.el-table__cell { background-color: #1d1d1d !important; }
                    html.dark .el-table tr { background-color: #141414 !important; }
                    html.dark .el-table--striped .el-table__body tr.el-table__row--striped td.el-table__cell { background: #1a1a1a !important; }
                    html.dark .el-table td.el-table__cell, html.dark .el-table th.el-table__cell { border-bottom-color: #414243 !important; }
                    html.dark .el-table--border .el-table__cell { border-right-color: #414243 !important; }
                    html.dark .el-table__empty-text { color: #8D9095 !important; }
                    html.dark .el-descriptions__label { color: #A3A6AD !important; }
                    html.dark .el-descriptions__content { color: #E5EAF3 !important; }
                    html.dark .el-empty__description p { color: #8D9095 !important; }
                    html.dark .el-form-item__label { color: #E5EAF3 !important; }
                    html.dark .el-dropdown-menu { background-color: #1d1d1d !important; border-color: #414243 !important; }
                    html.dark .el-dropdown-menu__item { color: #E5EAF3 !important; }
                    html.dark .el-dropdown-menu__item:hover { background-color: #252525 !important; }
                    html.dark .el-pagination { color: #A3A6AD !important; }

                    /* Inline style overrides via attribute selectors */
                    html.dark [style*="color: #303133"], html.dark [style*="color:#303133"] { color: #E5EAF3 !important; }
                    html.dark [style*="color: #606266"], html.dark [style*="color:#606266"] { color: #A3A6AD !important; }
                    html.dark [style*="color: #909399"], html.dark [style*="color:#909399"] { color: #8D9095 !important; }
                    html.dark [style*="color: #333"], html.dark [style*="color:#333"] { color: #E5EAF3 !important; }
                    html.dark [style*="color: #dcdfe6"], html.dark [style*="color:#dcdfe6"] { color: #4C4D4F !important; }
                    html.dark [style*="color: #004085"], html.dark [style*="color:#004085"] { color: #66b3ff !important; }
                    html.dark [style*="background: white"], html.dark [style*="background:white"] { background: #1d1d1d !important; }
                    html.dark [style*="background: #fff"], html.dark [style*="background:#fff"] { background: #1d1d1d !important; }
                    html.dark [style*="background-color: #fff"], html.dark [style*="background-color:#fff"] { background-color: #1d1d1d !important; }
                    html.dark [style*="background: #f5f7fa"], html.dark [style*="background:#f5f7fa"] { background: #0a0a0a !important; }
                    html.dark [style*="background: #f8f9fa"], html.dark [style*="background:#f8f9fa"] { background: #1a1a1a !important; }
                    html.dark [style*="background-color: #f8f9fa"], html.dark [style*="background-color:#f8f9fa"] { background-color: #1a1a1a !important; }
                    html.dark [style*="background-color: #e9ecef"], html.dark [style*="background-color:#e9ecef"] { background-color: #252525 !important; }
                    html.dark [style*="background-color: #cce5ff"], html.dark [style*="background-color:#cce5ff"] { background-color: rgba(64,158,255,0.15) !important; }
                `;

                const applyTypography = () => {
                    if (document.querySelector('[data-mikeagenda-typography]')) return;
                    const style = document.createElement('style');
                    style.setAttribute('data-mikeagenda-typography', 'true');
                    style.textContent = fontCSS + darkCSS;
                    (document.head || document.documentElement).appendChild(style);
                };

                const getColorMode = () => {
                    try {
                        return localStorage.getItem('__mikeagenda_colorMode') || 'system';
                    } catch (e) {
                        return 'system';
                    }
                };

                const notifyNative = (mode) => {
                    try {
                        window.webkit.messageHandlers.mikeAgendaColorMode.postMessage(mode);
                    } catch (e) {}
                };

                const applyColorMode = (mode, notify) => {
                    const html = document.documentElement;
                    let dark = false;
                    if (mode === 'dark') {
                        dark = true;
                    } else if (mode === 'light') {
                        dark = false;
                    } else {
                        dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
                    }

                    if (dark) {
                        html.classList.add('dark');
                    } else {
                        html.classList.remove('dark');
                    }

                    if (dark && !document.querySelector('link[data-mikeagenda-dark]')) {
                        const link = document.createElement('link');
                        link.rel = 'stylesheet';
                        link.href = '/vendor/element-plus/theme-chalk/dark/css-vars.css';
                        link.setAttribute('data-mikeagenda-dark', 'true');
                        (document.head || document.documentElement).appendChild(link);
                    }

                    applyTypography();

                    if (notify !== false) notifyNative(mode);
                };

                const mode = getColorMode();
                applyColorMode(mode);

                if (window.matchMedia) {
                    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
                        const currentMode = getColorMode();
                        if (currentMode === 'system') applyColorMode('system');
                    });
                }

                window.__mikeagenda_applyColorMode = applyColorMode;

                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', applyTypography, { once: true });
                }
            })();
            """
        }

        func attach(webView: WKWebView) {
            self.webView = webView
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            nil
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            scrollView.zoomScale = 1.0
        }

        func update(profile: ConnectionProfile) {
            self.profile = profile
            schemeHandler.update(profile: profile)

            if loadedToken != profile.reloadToken {
                loadEntryPage()
            }
        }

        func loadEntryPage() {
            guard let webView else {
                return
            }

            loadedToken = profile.reloadToken

            if profile.isComplete {
                showSplash()
                attemptSilentLogin()
            } else {
                webView.load(URLRequest(url: LocalSiteSchemeHandler.setupURL))
            }
        }

        private func showSplash() {
            let colorMode = ConnectionProfileStore.loadColorMode()
            let isDarkJS = colorMode == "dark" ? "true" : (colorMode == "system" ? "window.matchMedia('(prefers-color-scheme:dark)').matches" : "false")
            let html = """
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin:0; display:flex; align-items:center; justify-content:center;
                    height:100vh; font-family:-apple-system,PingFang SC,sans-serif;
                }
                body.dark { background:#0a0a0a; color:#E5EAF3; }
                body.light { background:#f5f7fa; color:#1d1d1f; }
                .spinner { width:28px; height:28px; border:3px solid rgba(128,128,128,0.25);
                    border-top-color:rgba(128,128,128,0.8); border-radius:50%;
                    animation:spin .7s linear infinite; margin-bottom:16px; }
                @keyframes spin { to { transform:rotate(360deg); } }
                .wrap { text-align:center; }
                .msg { font-size:15px; opacity:0.7; }
            </style>
            </head>
            <body>
            <div class="wrap">
                <div class="spinner" style="margin:0 auto 16px;"></div>
                <div class="msg">登录中…</div>
            </div>
            <script>document.body.classList.add(\(isDarkJS) ? 'dark' : 'light');</script>
            </body>
            </html>
            """
            webView?.loadHTMLString(html, baseURL: LocalSiteSchemeHandler.entryURL)
        }

        private func attemptSilentLogin() {
            guard let baseURL = profile.normalizedBaseURL else {
                navigateToLogin()
                return
            }

            // First check if existing session is still valid
            if let existingSession = persistedSessionValue(), !existingSession.isEmpty {
                var checkReq = URLRequest(url: baseURL.appendingPathComponent("api/getItems"))
                checkReq.httpMethod = "GET"
                checkReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                checkReq.setValue(existingSession, forHTTPHeaderField: "session")
                checkReq.timeoutInterval = 10

                URLSession.shared.dataTask(with: checkReq) { [weak self] data, response, error in
                    guard let self else { return }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status != 401, let data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       json["success"] as? Bool == true {
                        DispatchQueue.main.async {
                            self.navigateToDash()
                            self.fetchAndStartCourseActivity()
                        }
                    } else {
                        self.performLogin()
                    }
                }.resume()
                return
            }

            performLogin()
        }

        private func performLogin() {
            guard let baseURL = profile.normalizedBaseURL,
                  let loginURL = URL(string: baseURL.absoluteString + "/login") else {
                DispatchQueue.main.async { self.navigateToLogin() }
                return
            }

            var request = URLRequest(url: loginURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10

            let body: [String: String] = [
                "username": profile.trimmedUsername,
                "password": profile.password
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self else { return }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["success"] as? Bool == true,
                      let session = json["session"] as? String,
                      !session.isEmpty else {
                    DispatchQueue.main.async { self.navigateToLogin() }
                    return
                }

                ConnectionProfileStore.saveWebCookies("session=\(session)")
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript("document.cookie='session=\(session); path=/; SameSite=Lax';")
                    self.navigateToDash()
                    self.fetchAndStartCourseActivity()
                }
            }.resume()
        }

        private func persistedSessionValue() -> String? {
            let cookieString = ConnectionProfileStore.loadWebCookies()
            for cookie in cookieString.split(separator: ";") {
                let entry = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let separator = entry.firstIndex(of: "=") else { continue }
                let name = String(entry[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
                if name == "session" {
                    let valueIndex = entry.index(after: separator)
                    return String(entry[valueIndex...]).removingPercentEncoding ?? String(entry[valueIndex...])
                }
            }
            return nil
        }

        private func navigateToDash() {
            guard let dashURL = URL(string: "\(LocalSiteSchemeHandler.scheme)://\(LocalSiteSchemeHandler.host)/dash.html") else { return }
            webView?.load(URLRequest(url: dashURL))
        }

        private func navigateToLogin() {
            webView?.load(URLRequest(url: LocalSiteSchemeHandler.entryURL))
        }

        // MARK: - Course Live Activity

        private func fetchAndStartCourseActivity() {
            guard let baseURL = profile.normalizedBaseURL,
                  let session = persistedSessionValue(),
                  !session.isEmpty else { return }

            var request = URLRequest(url: baseURL.appendingPathComponent("api/getCourses"))
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(session, forHTTPHeaderField: "session")
            request.timeoutInterval = 10

            URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let self, let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["success"] as? Bool == true,
                      let courses = json["courses"] as? [[String: Any]] else { return }

                let now = Date()
                let calendar = Calendar.current
                // JS getDay(): 0=Sun. Swift weekday: 1=Sun → subtract 1
                let dayOfWeek = calendar.component(.weekday, from: now) - 1

                let todayCourses: [(code: String, name: String, venue: String, start: String, end: String, endDate: Date)] = courses.compactMap { c in
                    let isActive: Bool
                    if let intVal = c["is_active"] as? Int { isActive = intVal != 0 }
                    else if let boolVal = c["is_active"] as? Bool { isActive = boolVal }
                    else { return nil }

                    guard isActive,
                          let day = c["day"] as? Int,
                          day == dayOfWeek else { return nil }

                    let code = c["course_code"] as? String ?? ""
                    let name = c["course_name"] as? String ?? ""
                    let venue = c["venue"] as? String ?? ""
                    let startTime = c["start_time"] as? String ?? "00:00"
                    let endTime = c["end_time"] as? String ?? "00:00"

                    let endParts = endTime.split(separator: ":").compactMap { Int($0) }
                    guard endParts.count >= 2,
                          let endDate = calendar.date(bySettingHour: endParts[0], minute: endParts[1], second: 0, of: now),
                          endDate > now else { return nil }

                    return (code, name, venue, startTime, endTime, endDate)
                }.sorted { $0.start < $1.start }

                DispatchQueue.main.async {
                    self.applyCourseActivity(todayCourses)
                }
            }.resume()
        }

        private func applyCourseActivity(_ courses: [(code: String, name: String, venue: String, start: String, end: String, endDate: Date)]) {
            courseTimer?.invalidate()
            courseTimer = nil

            guard !courses.isEmpty,
                  ActivityAuthorizationInfo().areActivitiesEnabled else {
                endAllCourseActivities()
                return
            }

            let current = courses[0]
            let remaining = Array(courses.dropFirst())

            let state = CourseActivityAttributes.ContentState(
                courseCode: current.code,
                courseName: current.name,
                venue: current.venue,
                startTime: current.start,
                endTime: current.end
            )

            // Update existing or start new
            let existingActivities = Activity<CourseActivityAttributes>.activities
            if let existing = existingActivities.first {
                Task {
                    await existing.update(ActivityContent(state: state, staleDate: current.endDate))
                }
            } else {
                let attributes = CourseActivityAttributes()
                let content = ActivityContent(state: state, staleDate: current.endDate)
                do {
                    _ = try Activity.request(attributes: attributes, content: content)
                } catch {
                    print("Failed to start course activity: \(error)")
                }
            }

            // Schedule timer for when current course ends
            courseTimer = Timer.scheduledTimer(withTimeInterval: current.endDate.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                guard let self else { return }
                if remaining.isEmpty {
                    self.endAllCourseActivities()
                } else {
                    self.applyCourseActivity(remaining)
                }
            }
        }

        private func endAllCourseActivities() {
            courseTimer?.invalidate()
            courseTimer = nil
            for activity in Activity<CourseActivityAttributes>.activities {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == Self.cookieHandlerName,
               let body = message.body as? [String: Any],
               let value = body["value"] as? String {
                ConnectionProfileStore.saveWebCookies(value)
                return
            }

            if message.name == Self.configHandlerName,
               let body = message.body as? [String: Any],
               let action = body["action"] as? String {
                handleConfigMessage(action: action, body: body)
                return
            }

            if message.name == Self.colorModeHandlerName,
               let mode = message.body as? String {
                onColorModeChanged?(mode)
                return
            }
        }

        private func handleConfigMessage(action: String, body: [String: Any]) {
            switch action {
            case "save":
                let newProfile = ConnectionProfile(
                    domain: body["domain"] as? String ?? "",
                    username: body["username"] as? String ?? "",
                    password: body["password"] as? String ?? ""
                )
                let didChange = newProfile.reloadToken != profile.reloadToken
                ConnectionProfileStore.save(newProfile)
                if didChange {
                    ConnectionProfileStore.clearWebCookies()
                }
                profile = ConnectionProfileStore.load()
                schemeHandler.update(profile: profile)
                loadedToken = nil
                onProfileChanged?()
            case "clear":
                ConnectionProfileStore.clear()
                profile = ConnectionProfile()
                schemeHandler.update(profile: profile)
                loadedToken = nil
                onProfileChanged?()
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleLoadError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleLoadError(error)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url else {
                return nil
            }

            webView.load(URLRequest(url: url))
            return nil
        }

        private var prefillLoginScript: String {
            let username = profile.trimmedUsername.jsEscapedLiteral
            let password = profile.password.jsEscapedLiteral

            return """
            (() => {
                const username = \(username);
                const password = \(password);
                if (!username || !password) return;

                const tryLogin = () => {
                    const appEl = document.getElementById('app');
                    if (!appEl || !appEl.__vue_app__) {
                        window.setTimeout(tryLogin, 100);
                        return;
                    }

                    const vm = appEl.__vue_app__._instance;
                    if (!vm || !vm.setupState) {
                        window.setTimeout(tryLogin, 100);
                        return;
                    }

                    const state = vm.setupState;
                    if (state.loginForm) {
                        state.loginForm.username = username;
                        state.loginForm.password = password;
                    }

                    if (typeof state.handleLogin === 'function') {
                        window.setTimeout(() => state.handleLogin(), 50);
                    }
                };

                tryLogin();
            })();
            """
        }

        var profileInjectionScript: String {
            let domain = profile.trimmedDomain.jsEscapedLiteral
            let username = profile.trimmedUsername.jsEscapedLiteral
            let password = profile.password.jsEscapedLiteral
            return "window.__mikeagenda_profile = { domain: \(domain), username: \(username), password: \(password) };"
        }

        private func handleLoadError(_ error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }

            guard let webView else {
                return
            }

            let html = """
            <html>
            <body style='font-family:-apple-system;padding:24px;background:#f5f5f7;color:#1d1d1f;'>
                <h2 style='margin:0 0 12px;'>无法加载页面</h2>
                <p style='line-height:1.6;'>\(error.localizedDescription.htmlEscaped)</p>
                <p style='line-height:1.6;color:#6e6e73;'>请前往设置页面检查连接配置。</p>
            </body>
            </html>
            """

            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}

final class LocalSiteSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "mikeagenda"
    static let host = "app"
    static let entryURL = URL(string: "\(scheme)://\(host)/")!
    static let setupURL = URL(string: "\(scheme)://\(host)/setup.html")!

    private let session = URLSession(configuration: .default)
    private var profile: ConnectionProfile
    private var activeTasks: [ObjectIdentifier: URLSessionTask] = [:]
    private let lock = NSLock()

    init(profile: ConnectionProfile) {
        self.profile = profile
    }

    func update(profile: ConnectionProfile) {
        self.profile = profile
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            send(statusCode: 400, data: Data("Bad request".utf8), mimeType: "text/plain", to: urlSchemeTask)
            return
        }

        if shouldProxy(path: url.path) {
            proxyRequest(for: urlSchemeTask)
            return
        }

        serveLocalResource(for: urlSchemeTask)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let identifier = ObjectIdentifier(urlSchemeTask as AnyObject)
        lock.lock()
        let task = activeTasks.removeValue(forKey: identifier)
        lock.unlock()
        task?.cancel()
    }

    private func shouldProxy(path: String) -> Bool {
        path == "/login"
            || path.hasPrefix("/api/")
            || path.hasPrefix("/mtr/")
            || path.hasPrefix("/farm/")
    }

    private func proxyRequest(for urlSchemeTask: WKURLSchemeTask) {
        guard let remoteURL = resolvedRemoteURL(for: urlSchemeTask.request.url) else {
            send(statusCode: 500, data: Data("Invalid remote URL".utf8), mimeType: "text/plain", to: urlSchemeTask)
            return
        }

        var request = URLRequest(url: remoteURL)
        request.httpMethod = urlSchemeTask.request.httpMethod
        request.httpBody = bodyData(for: urlSchemeTask.request)
        request.timeoutInterval = 25

        for (header, value) in urlSchemeTask.request.allHTTPHeaderFields ?? [:] {
            let normalized = header.lowercased()
            if normalized == "origin" || normalized == "referer" || normalized == "host" {
                continue
            }
            request.setValue(value, forHTTPHeaderField: header)
        }

        if request.value(forHTTPHeaderField: "session") == nil,
           let persistedSession = persistedSessionValue(),
           !persistedSession.isEmpty {
            request.setValue(persistedSession, forHTTPHeaderField: "session")
        }

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            self.finishActiveTask(for: urlSchemeTask)

            if let error {
                DispatchQueue.main.async {
                    urlSchemeTask.didFailWithError(error)
                }
                return
            }

            let responseData = data ?? Data()
            let remoteResponse = response as? HTTPURLResponse
            let statusCode = remoteResponse?.statusCode ?? 200
            var headers = remoteResponse?.allHeaderFields as? [String: String] ?? [:]
            if headers["Content-Type"] == nil, let mimeType = remoteResponse?.mimeType {
                headers["Content-Type"] = mimeType
            }

            self.updatePersistedSession(for: urlSchemeTask.request.url, statusCode: statusCode, data: responseData)

            let httpResponse = HTTPURLResponse(
                url: urlSchemeTask.request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!

            DispatchQueue.main.async {
                urlSchemeTask.didReceive(httpResponse)
                urlSchemeTask.didReceive(responseData)
                urlSchemeTask.didFinish()
            }
        }

        storeActiveTask(task, for: urlSchemeTask)
        task.resume()
    }

    private func serveLocalResource(for urlSchemeTask: WKURLSchemeTask) {
        guard let fileURL = localResourceURL(for: urlSchemeTask.request.url) else {
            send(statusCode: 404, data: Data("Not found".utf8), mimeType: "text/plain", to: urlSchemeTask)
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType = mimeType(for: fileURL)
            send(statusCode: 200, data: data, mimeType: mimeType, to: urlSchemeTask)
        } catch {
            send(statusCode: 500, data: Data(error.localizedDescription.utf8), mimeType: "text/plain", to: urlSchemeTask)
        }
    }

    private func send(statusCode: Int, data: Data, mimeType: String, to urlSchemeTask: WKURLSchemeTask) {
        let response = HTTPURLResponse(
            url: urlSchemeTask.request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mimeType]
        )!

        DispatchQueue.main.async {
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }
    }

    private func resolvedRemoteURL(for localURL: URL?) -> URL? {
        guard let localURL,
              let baseURL = profile.normalizedBaseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = localURL.path
        components.query = localURL.query
        components.fragment = nil
        return components.url
    }

    private func persistedSessionValue() -> String? {
        let cookieString = ConnectionProfileStore.loadWebCookies()
        for cookie in cookieString.split(separator: ";") {
            let entry = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = entry.firstIndex(of: "=") else {
                continue
            }

            let name = String(entry[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            if name == "session" {
                let valueIndex = entry.index(after: separator)
                return String(entry[valueIndex...]).removingPercentEncoding ?? String(entry[valueIndex...])
            }
        }

        return nil
    }

    private func updatePersistedSession(for requestURL: URL?, statusCode: Int, data: Data) {
        guard let requestURL else {
            return
        }

        if requestURL.path == "/login",
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           (json["success"] as? Bool) == true,
           let session = json["session"] as? String,
           !session.isEmpty {
            ConnectionProfileStore.saveWebCookies("session=\(session)")
            return
        }

        if statusCode == 401 {
            ConnectionProfileStore.clearWebCookies()
        }
    }

    private func localResourceURL(for requestURL: URL?) -> URL? {
        guard let requestURL,
              let bundleURL = Bundle.main.url(forResource: "Site", withExtension: "bundle") else {
            return nil
        }

        let rawPath = requestURL.path.removingPercentEncoding ?? requestURL.path
        let resolvedPath: String
        if rawPath == "/" || rawPath.isEmpty {
            resolvedPath = "login.html"
        } else {
            resolvedPath = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        let candidateURL = bundleURL.appendingPathComponent(resolvedPath)
        let normalizedBundlePath = bundleURL.standardizedFileURL.path + "/"
        let normalizedCandidatePath = candidateURL.standardizedFileURL.path

        guard normalizedCandidatePath.hasPrefix(normalizedBundlePath) || normalizedCandidatePath == bundleURL.standardizedFileURL.path,
              FileManager.default.fileExists(atPath: normalizedCandidatePath) else {
            return nil
        }

        return URL(fileURLWithPath: normalizedCandidatePath)
    }

    private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "html":
            return "text/html; charset=utf-8"
        case "css":
            return "text/css; charset=utf-8"
        case "js":
            return "text/javascript; charset=utf-8"
        case "json":
            return "application/json; charset=utf-8"
        case "svg":
            return "image/svg+xml; charset=utf-8"
        case "woff":
            return "font/woff"
        case "woff2":
            return "font/woff2"
        case "ttf":
            return "font/ttf"
        case "eot":
            return "application/vnd.ms-fontobject"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "ico":
            return "image/x-icon"
        default:
            if let type = UTType(filenameExtension: fileURL.pathExtension),
               let preferred = type.preferredMIMEType {
                return preferred
            }
            return "application/octet-stream"
        }
    }

    private func bodyData(for request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        let data = NSMutableData()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                return nil
            }
            if read == 0 {
                break
            }
            data.append(buffer, length: read)
        }

        return data as Data
    }

    private func storeActiveTask(_ task: URLSessionTask, for urlSchemeTask: WKURLSchemeTask) {
        lock.lock()
        activeTasks[ObjectIdentifier(urlSchemeTask as AnyObject)] = task
        lock.unlock()
    }

    private func finishActiveTask(for urlSchemeTask: WKURLSchemeTask) {
        lock.lock()
        activeTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask as AnyObject))
        lock.unlock()
    }
}
