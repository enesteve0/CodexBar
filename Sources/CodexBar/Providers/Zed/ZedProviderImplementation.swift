import AppKit
import CodexBarCore
import CodexBarMacroSupport
import Foundation
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
                        Imports dashboard.zed.dev session cookies from Chrome and fetches live token spend from \
                        cloud.zed.dev/frontend/billing/usage.
                        """,
                        manual: """
                        Uses a pasted dashboard.zed.dev cookie header to fetch live token spend from the undocumented \
                        dashboard billing API.
                        """,
                        off: "Dashboard cookie access is disabled. This is the default and causes no browser prompts.")
                },
                binding: cookieBinding,
                options: options,
                isVisible: nil,
                onChange: nil,
                trailingText: nil),
        ]
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "zed-cookie-header",
                title: "",
                subtitle: """
                Paste the Cookie request header from a signed-in dashboard.zed.dev billing page. \
                Editor Keychain sign-in is separate.
                """,
                kind: .secure,
                placeholder: "name=value; name2=value2",
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
