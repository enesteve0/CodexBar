import CodexBarCore
import Foundation

extension SettingsStore {
    var zedCookieSource: ProviderCookieSource {
        get { self.resolvedCookieSource(provider: .zed, fallback: .off) }
        set {
            self.updateProviderConfig(provider: .zed) { entry in
                entry.cookieSource = newValue
            }
            self.logProviderModeChange(provider: .zed, field: "cookieSource", value: newValue.rawValue)
        }
    }

    var zedCookieHeader: String {
        get { self.configSnapshot.providerConfig(for: .zed)?.sanitizedCookieHeader ?? "" }
        set {
            self.updateProviderConfig(provider: .zed) { entry in
                entry.cookieHeader = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .zed, field: "cookieHeader", value: newValue)
        }
    }

    func zedSettingsSnapshot() -> ProviderSettingsSnapshot.ZedProviderSettings {
        let header = self.zedCookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProviderSettingsSnapshot.ZedProviderSettings(
            cookieSource: self.zedCookieSource,
            manualCookieHeader: header.isEmpty ? nil : header)
    }
}
