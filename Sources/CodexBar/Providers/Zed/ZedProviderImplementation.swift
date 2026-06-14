import AppKit
import CodexBarCore
import CodexBarMacroSupport
import Foundation
import SweetCookieKit
import SwiftUI

@ProviderImplementationRegistration
struct ZedProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .zed

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings.zedCookieSource
        _ = settings.zedCookieHeader
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        .zed(context.settings.zedSettingsSnapshot())
    }

    @MainActor
    func settingsPickers(context: ProviderSettingsContext) -> [ProviderSettingsPickerDescriptor] {
        let cookieBinding = Binding(
            get: { context.settings.zedCookieSource.rawValue },
            set: { rawValue in
                context.settings.zedCookieSource = ProviderCookieSource(rawValue: rawValue) ?? .off
            })
        let options = ProviderCookieSourceUI.options(
            allowsOff: true,
            keychainDisabled: context.settings.debugDisableKeychainAccess)
        let autoBrowserHint =
            ProviderDefaults.metadata[.zed]?.browserCookieOrder?.loginHint ?? Browser.chrome.displayName

        return [
            ProviderSettingsPickerDescriptor(
                id: "zed-cookie-source",
                title: "Dashboard cookie source",
                subtitle: """
                Optional and experimental. The editor Keychain session still provides plan and Edit Predictions usage.
                """,
                dynamicSubtitle: {
                    ProviderCookieSourceUI.subtitle(
                        source: context.settings.zedCookieSource,
                        keychainDisabled: context.settings.debugDisableKeychainAccess,
                        auto: """
                        Imports zed.session from \(autoBrowserHint) and fetches \
                        live token spend from cloud.zed.dev/frontend/billing/usage.
                        """,
                        manual: """
                        Paste the Request Cookie header from a signed-in cloud.zed.dev/frontend/billing/usage request. \
                        It must include zed.session=….
                        """,
                        off: "Dashboard cookie access is disabled. This is the default and causes no browser prompts.")
                },
                binding: cookieBinding,
                options: options,
                isVisible: nil,
                onChange: { _ in
                    await context.store.refreshProvider(.zed, allowDisabled: true)
                },
                trailingText: {
                    guard context.settings.zedCookieSource != .off else { return nil }
                    if let error = context.store.snapshot(for: .zed)?
                        .extraRateWindows?
                        .first(where: { $0.id == "zed.token-billing-error" })?
                        .window.resetDescription
                    {
                        return error
                    }
                    if context.store.sourceLabel(for: .zed).contains("local+zed-dashboard") {
                        return "Live dashboard token spend loaded."
                    }
                    return nil
                }),
        ]
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "zed-cookie-header",
                title: "",
                subtitle: """
                1. Sign in at dashboard.zed.dev
                2. DevTools → Network → filter billing/usage
                3. Open the cloud.zed.dev/frontend/billing/usage request
                4. Copy Request Headers → Cookie (must include zed.session=…)
                5. Do not copy Response Set-Cookie lines or __cf_bm alone
                """,
                kind: .secure,
                placeholder: "zed.session=…; __cf_bm=…",
                binding: context.stringBinding(\.zedCookieHeader),
                actions: [],
                isVisible: { context.settings.zedCookieSource == .manual },
                onActivate: nil),
        ]
    }

    @MainActor
    func settingsActions(context _: ProviderSettingsContext) -> [ProviderSettingsActionsDescriptor] {
        [
            ProviderSettingsActionsDescriptor(
                id: "zed-sign-in",
                title: "Zed sign-in",
                subtitle: """
                Sign in from the Zed editor app (GitHub). CodexBar reads that Keychain session for plan and Edit \
                Predictions. Live token spend requires a separate dashboard.zed.dev browser login plus optional cookie \
                import above.
                """,
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "zed-open-billing-dashboard",
                        title: "Open Billing Dashboard",
                        style: .link,
                        isVisible: nil,
                        perform: {
                            if let url = URL(string: "https://dashboard.zed.dev") {
                                NSWorkspace.shared.open(url)
                            }
                        }),
                ],
                isVisible: nil),
        ]
    }
}
