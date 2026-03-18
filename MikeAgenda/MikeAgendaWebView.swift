import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct MikeAgendaWebView: UIViewRepresentable {
    let profile: ConnectionProfile
    var onProfileChanged: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(profile: profile, onProfileChanged: onProfileChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: Coordinator.cookieHandlerName)
        userContentController.add(context.coordinator, name: Coordinator.configHandlerName)
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

        private(set) var profile: ConnectionProfile
        let schemeHandler: LocalSiteSchemeHandler
        private weak var webView: WKWebView?
        private var loadedToken: String?
        private var onProfileChanged: (() -> Void)?

        init(profile: ConnectionProfile, onProfileChanged: (() -> Void)?) {
            self.profile = profile
            self.onProfileChanged = onProfileChanged
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
                const applyTypography = () => {
                    const style = document.createElement('style');
                    style.setAttribute('data-mikeagenda-typography', 'true');
                    style.textContent = `
                        html, body, button, input, textarea, select, option,
                        .el-button, .el-input__inner, .el-input__wrapper, .el-textarea__inner,
                        .el-select, .el-dropdown-menu, .el-dialog, .el-message-box {
                            font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif !important;
                        }
                        html.dark body { background: #0a0a0a; color: #E5EAF3; }
                    `;
                    (document.head || document.documentElement).appendChild(style);
                };

                const getColorMode = () => {
                    try {
                        return localStorage.getItem('__mikeagenda_colorMode') || 'system';
                    } catch (e) {
                        return 'system';
                    }
                };

                const applyColorMode = (mode) => {
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
                };

                const mode = getColorMode();
                applyColorMode(mode);

                if (mode === 'system' && window.matchMedia) {
                    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
                        const currentMode = getColorMode();
                        if (currentMode === 'system') applyColorMode('system');
                    });
                }

                window.__mikeagenda_applyColorMode = applyColorMode;

                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', applyTypography, { once: true });
                }

                applyTypography();
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
                webView.load(URLRequest(url: LocalSiteSchemeHandler.entryURL))
            } else {
                webView.load(URLRequest(url: LocalSiteSchemeHandler.setupURL))
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
            let page = webView.url?.lastPathComponent.lowercased() ?? ""

            if page == "login.html" {
                webView.evaluateJavaScript(prefillLoginScript)
            }
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
