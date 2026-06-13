import Foundation

#if os(macOS)
import SweetCookieKit

private let zedCookieImportOrder: BrowserCookieImportOrder =
    ProviderDefaults.metadata[.zed]?.browserCookieOrder ?? Browser.defaultImportOrder

public enum ZedCookieImporter {
    private static let cookieClient = BrowserCookieClient()
    private static let cookieDomains = [
        "cloud.zed.dev",
        "dashboard.zed.dev",
        "zed.dev",
    ]

    public struct SessionInfo: Sendable {
        public let cookies: [HTTPCookie]
        public let sourceLabel: String

        public init(cookies: [HTTPCookie], sourceLabel: String) {
            self.cookies = cookies
            self.sourceLabel = sourceLabel
        }

        public var cookieHeader: String {
            self.cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }
    }

    public static func importSession(
        browserDetection: BrowserDetection,
        logger: ((String) -> Void)? = nil) throws -> SessionInfo
    {
        let log: (String) -> Void = { logger?("[zed-cookie] \($0)") }
        for browser in zedCookieImportOrder.cookieImportCandidates(using: browserDetection) {
            if let session = self.importSessionIfPresent(
                browser: browser,
                browserDetection: browserDetection,
                logger: logger)
            {
                return session
            }
            if let session = self.importDomainCookiesIfPresent(
                browser: browser,
                browserDetection: browserDetection,
                logger: logger)
            {
                return session
            }
        }

        log("No Zed dashboard cookies found in configured browsers")
        throw ZedDashboardBillingError.noSessionCookie
    }

    static func importSessionIfPresent(
        browser: Browser,
        browserDetection: BrowserDetection,
        logger: ((String) -> Void)? = nil) -> SessionInfo?
    {
        self.importCookiesFromBrowser(
            browser: browser,
            browserDetection: browserDetection,
            requireKnownSessionName: true,
            logger: logger).first
    }

    static func importDomainCookiesIfPresent(
        browser: Browser,
        browserDetection: BrowserDetection,
        logger: ((String) -> Void)? = nil) -> SessionInfo?
    {
        self.importCookiesFromBrowser(
            browser: browser,
            browserDetection: browserDetection,
            requireKnownSessionName: false,
            logger: logger).first
    }

    private static func importCookiesFromBrowser(
        browser: Browser,
        browserDetection: BrowserDetection,
        requireKnownSessionName: Bool,
        logger: ((String) -> Void)?) -> [SessionInfo]
    {
        let log: (String) -> Void = { logger?("[zed-cookie] \($0)") }
        guard browserDetection.isCookieSourceAvailable(browser) else { return [] }
        guard BrowserCookieAccessGate.shouldAttempt(browser) else { return [] }

        do {
            let query = BrowserCookieQuery(domains: Self.cookieDomains)
            let sources = try Self.cookieClient.codexBarRecords(
                matching: query,
                in: browser,
                logger: log)
            var sessions: [SessionInfo] = []
            for source in sources where !source.records.isEmpty {
                let filteredRecords = if requireKnownSessionName {
                    source.records.filter { ZedCookieHeader.isSessionCookieName($0.name) }
                } else {
                    source.records
                }
                guard !filteredRecords.isEmpty else { continue }
                let cookies = BrowserCookieClient.makeHTTPCookies(filteredRecords, origin: query.origin)
                guard !cookies.isEmpty, ZedCookieHeader.hasSessionCookie(cookies) else { continue }
                let labelSuffix = requireKnownSessionName ? "session cookies" : "domain cookies"
                log("Found \(cookies.count) Zed dashboard \(labelSuffix) in \(source.label)")
                sessions.append(SessionInfo(
                    cookies: cookies,
                    sourceLabel: "\(source.label) (\(labelSuffix))"))
            }
            return sessions
        } catch {
            BrowserCookieAccessGate.recordIfNeeded(error)
            log("\(browser.displayName) cookie import failed: \(error.localizedDescription)")
            return []
        }
    }
}
#endif
