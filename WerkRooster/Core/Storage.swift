import Foundation

final class Storage {
    private let key = "roosterplanner.auth.config"

    func loadConfig() -> AuthConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AuthConfig.self, from: data)
    }

    func saveConfig(_ config: AuthConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
