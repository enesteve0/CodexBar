import Foundation

public enum ZedCookieHeader {
    public static let sessionCookieName = "zed.session"

    private static let legacySessionCookieNames: Set<String> = [
        "session",
        "__Host-session",
        "__Secure-session",
        "zed_session",
        "__Secure-zed_session",
    ]

    public static let ancillaryCookieNames: Set<String> = [
        "__cf_bm",
    ]

    public static func hasSessionCookie(_ raw: String?) -> Bool {
        CookieHeaderNormalizer.pairs(from: raw ?? "").contains { self.isSessionCookieName($0.name) }
    }

    public static func hasDashboardSessionCookie(_ raw: String?) -> Bool {
        CookieHeaderNormalizer.pairs(from: raw ?? "").contains { $0.name == self.sessionCookieName }
    }

    #if os(macOS)
    public static func hasSessionCookie(_ cookies: [HTTPCookie]) -> Bool {
        cookies.contains { self.isSessionCookieName($0.name) }
    }
    #endif

    public static func isCloudflareOnly(_ raw: String?) -> Bool {
        let pairs = CookieHeaderNormalizer.pairs(from: raw ?? "")
        guard !pairs.isEmpty else { return false }
        return pairs.allSatisfy { pair in
            pair.name == "__cf_bm" || pair.name == "_rdt_uuid"
        }
    }

    /// Billing requests require the live dashboard cookie name (`zed.session`), not legacy aliases.
    public static func filteredBillingHeader(from cookieHeader: String) -> String? {
        let pairs = CookieHeaderNormalizer.pairs(from: cookieHeader)
        guard pairs.contains(where: { $0.name == self.sessionCookieName }) else { return nil }
        let allowedNames = self.ancillaryCookieNames.union([self.sessionCookieName])
        let filtered = pairs.filter { allowedNames.contains($0.name) }
        return filtered.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    public static func isSessionCookieName(_ name: String) -> Bool {
        if name == self.sessionCookieName { return true }
        return self.legacySessionCookieNames.contains(name)
    }
}
