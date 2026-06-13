import CodexBarCore
import Foundation
import Testing

struct ZedDashboardBillingTests {
    private static func proResponse() throws -> ZedAuthenticatedUserResponse {
        let url = Bundle.module.url(
            forResource: "users-me-pro",
            withExtension: "json",
            subdirectory: "Fixtures/Zed")!
        return try ZedStatusProbe.parseResponse(Data(contentsOf: url))
    }

    private static func fixtureData(named name: String) throws -> Data {
        let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures/Zed")!
        return try Data(contentsOf: url)
    }

    @Test
    func `provider settings default dashboard cookies off`() {
        let settings = ProviderSettingsSnapshot.ZedProviderSettings()

        #expect(settings.cookieSource == .off)
        #expect(settings.manualCookieHeader == nil)
    }

    @Test
    func `off source preserves phase one static token labels`() async throws {
        let billing = try await ZedDashboardBillingFetcher.fetch(
            browserDetection: BrowserDetection(),
            cookieSource: .off,
            manualCookieHeader: nil)
        let snapshot = try ZedUsageSnapshot(response: Self.proResponse()).toUsageSnapshot(tokenBilling: billing)

        #expect(billing == nil)
        #expect(snapshot.extraRateWindows?.contains(where: { $0.id == "zed.token-spend-note" }) == true)
        #expect(snapshot.extraRateWindows?.first(where: { $0.id == "zed.token-credits" })?.usageKnown == false)
    }

    @Test
    func `empty manual source is rejected before any request`() async {
        await #expect(throws: ZedDashboardBillingError.invalidManualCookie) {
            _ = try await ZedDashboardBillingFetcher.fetch(
                browserDetection: BrowserDetection(),
                cookieSource: .manual,
                manualCookieHeader: "  ")
        }
    }

    @Test
    func `parses pro billing usage fixture`() throws {
        let billing = try ZedDashboardBillingFetcher.parseResponse(Self.fixtureData(named: "billing-usage-pro"))

        #expect(billing.spentUSD == 1.25)
        #expect(billing.includedUSD == 5)
        #expect(billing.spendLimitUSD == nil)
    }

    @Test
    func `parses spend limit fixture with included and threshold`() throws {
        let billing = try ZedDashboardBillingFetcher.parseResponse(
            Self.fixtureData(named: "billing-usage-spend-limit"))

        #expect(billing.spentUSD == 6)
        #expect(billing.includedUSD == 5)
        #expect(billing.spendLimitUSD == 15)
    }

    @Test
    func `manual source fetches billing usage with stub transport`() async throws {
        let fixture = try Self.fixtureData(named: "billing-usage-pro")
        let transport = ProviderHTTPTransportStub { request in
            #expect(request.url?.absoluteString == ZedDashboardBillingFetcher.billingUsageURL.absoluteString)
            #expect(request.value(forHTTPHeaderField: "Cookie") == "session=redacted")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!
            return (fixture, response)
        }

        let billing = try await ZedDashboardBillingFetcher.fetch(
            browserDetection: BrowserDetection(),
            cookieSource: .manual,
            manualCookieHeader: "session=redacted",
            transport: transport)

        #expect(billing?.spentUSD == 1.25)
        #expect(billing?.includedUSD == 5)
    }

    @Test
    func `typed billing snapshot replaces static token windows`() throws {
        let billing = ZedTokenBillingSnapshot(
            spentUSD: 1.25,
            includedUSD: 5,
            spendLimitUSD: nil,
            periodEnd: nil)
        let snapshot = try ZedUsageSnapshot(response: Self.proResponse()).toUsageSnapshot(tokenBilling: billing)
        let tokenWindow = snapshot.extraRateWindows?.first(where: { $0.id == "zed.token-credits" })

        #expect(snapshot.extraRateWindows?.contains(where: { $0.id == "zed.token-spend-note" }) == false)
        #expect(tokenWindow?.usageKnown == true)
        #expect(tokenWindow?.window.usedPercent == 25)
        #expect(tokenWindow?.window.resetDescription == "$1.25 of $5.00 included")
    }

    @Test
    func `billing snapshot uses larger live spend limit denominator`() throws {
        let billing = ZedTokenBillingSnapshot(
            spentUSD: 6,
            includedUSD: 5,
            spendLimitUSD: 15,
            periodEnd: nil)
        let snapshot = try ZedUsageSnapshot(response: Self.proResponse()).toUsageSnapshot(tokenBilling: billing)
        let tokenWindow = snapshot.extraRateWindows?.first(where: { $0.id == "zed.token-credits" })

        #expect(tokenWindow?.usageKnown == true)
        #expect(tokenWindow?.window.usedPercent == 40)
        #expect(tokenWindow?.window.resetDescription == "$6.00 / $15.00")
    }

    @Test
    func `parse failure keeps phase one labels when billing is nil`() throws {
        let snapshot = try ZedUsageSnapshot(response: Self.proResponse()).toUsageSnapshot(tokenBilling: nil)

        #expect(snapshot.extraRateWindows?.contains(where: { $0.id == "zed.token-spend-note" }) == true)
        #expect(snapshot.extraRateWindows?.first(where: { $0.id == "zed.token-credits" })?.usageKnown == false)
    }

    @Test
    func `unauthorized billing response surfaces auth error`() async {
        let transport = ProviderHTTPTransportStub { _ in
            let response = HTTPURLResponse(
                url: ZedDashboardBillingFetcher.billingUsageURL,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil)!
            return (Data("{}".utf8), response)
        }

        await #expect(throws: ZedDashboardBillingError.unauthorized) {
            _ = try await ZedDashboardBillingFetcher.fetch(
                browserDetection: BrowserDetection(),
                cookieSource: .manual,
                manualCookieHeader: "session=redacted",
                transport: transport)
        }
    }
}
