import Foundation
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    enum Dest: String, CaseIterable, Identifiable {
        case dashboard
        case schedule
        case availability
        case profile
        case chat
        case sick
        case notifications

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .schedule: return "Rooster"
            case .availability: return "Beschikbaarheid"
            case .profile: return "Mijn Profiel"
            case .chat: return "Chat"
            case .sick: return "Ziek melden"
            case .notifications: return "Meldingen"
            }
        }

        var symbol: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .schedule: return "calendar"
            case .availability: return "checkmark.calendar"
            case .profile: return "person"
            case .chat: return "bubble.left.and.bubble.right"
            case .sick: return "cross.case"
            case .notifications: return "bell"
            }
        }
    }

    @Published var config: AuthConfig?
    @Published var me: MeResponse?
    @Published var schedules: [ScheduleItem] = []
    @Published var notifications: [NotificationItem] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var shifts: [Shift] = []
    @Published var availabilityEntries: [String: AvailabilityEntryRequest] = [:]
    @Published var availabilityStatus: String?
    @Published var loading = false
    @Published var error: String?
    @Published var currentDest: Dest = .dashboard
    @Published var selectedMonth: Date = Date()
    @Published var teamPhone: String? = "+31638993687"

    private let storage = Storage()
    private let api = APIClient()
    private var chatTask: Task<Void, Never>?

    var nextShift: ScheduleItem? {
        let today = DateFormatter.isoDate.string(from: Date())
        return schedules.first { $0.workDate >= today }
    }

    var locationId: Int {
        me?.locations.first?.id ?? 0
    }

    var currentUserId: Int {
        me?.user.id ?? 0
    }

    func bootstrap() async {
        config = storage.loadConfig()
        guard config != nil else { return }
        await loadSessionData()
    }

    func login(baseUrl: String, username: String, password: String) async {
        guard !baseUrl.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Voer een geldige site URL in."
            return
        }

        loading = true
        error = nil
        defer { loading = false }

        do {
            let response = try await api.login(
                baseUrl: baseUrl,
                body: LoginRequest(
                    username: username,
                    password: password,
                    deviceId: UIDevice.current.identifierForVendor?.uuidString
                )
            )
            let newConfig = AuthConfig(
                baseUrl: baseUrl,
                username: username,
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            config = newConfig
            storage.saveConfig(newConfig)
            await loadSessionData()
        } catch {
            self.error = "Inloggen mislukt: \(error.localizedDescription)"
        }
    }

    func logout() async {
        chatTask?.cancel()
        if let config, let refreshToken = config.refreshToken {
            _ = try? await api.logout(baseUrl: config.baseUrl, token: config.accessToken, body: LogoutRequest(refreshToken: refreshToken))
        }
        clearSession()
    }

    func refreshSchedules(daysAhead: Int = 30) async {
        guard let config else { return }
        do {
            let start = DateFormatter.isoDate.string(from: Date())
            let end = DateFormatter.isoDate.string(from: Calendar.current.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date())
            schedules = try await authorized {
                try await api.schedules(baseUrl: config.baseUrl, token: self.config?.accessToken, startDate: start, endDate: end)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSchedules(start: String, end: String) async {
        guard let config else { return }
        do {
            schedules = try await authorized {
                try await api.schedules(baseUrl: config.baseUrl, token: self.config?.accessToken, startDate: start, endDate: end)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadNotifications() async {
        guard let config else { return }
        do {
            notifications = try await authorized {
                try await api.notifications(baseUrl: config.baseUrl, token: self.config?.accessToken)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markNotificationRead(id: Int) async {
        guard let config else { return }
        do {
            _ = try await authorized {
                try await api.markNotificationRead(baseUrl: config.baseUrl, token: self.config?.accessToken, id: id)
            } as Void
            await loadNotifications()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadAvailability(for monthString: String) async {
        guard let config, locationId != 0 else { return }
        loading = true
        availabilityStatus = nil
        defer { loading = false }

        do {
            let response = try await authorized {
                try await api.availability(baseUrl: config.baseUrl, token: self.config?.accessToken, month: monthString, locationId: self.locationId)
            }

            var map = buildMonthDefaults(monthString: monthString)
            for item in response.items {
                map[item.workDate] = AvailabilityEntryRequest(
                    date: item.workDate,
                    isAvailable: item.isAvailable == 1,
                    shiftPreference: item.shiftPreference,
                    customStart: item.customStart,
                    customEnd: item.customEnd,
                    notes: item.notes
                )
            }
            availabilityEntries = map
        } catch {
            availabilityStatus = "Kon beschikbaarheid niet laden"
        }
    }

    func saveAvailability() async {
        guard let config, locationId != 0 else { return }
        loading = true
        defer { loading = false }

        do {
            let body = AvailabilityUpsertRequest(locationId: locationId, entries: Array(availabilityEntries.values))
            _ = try await authorized {
                try await api.upsertAvailability(baseUrl: config.baseUrl, token: self.config?.accessToken, body: body)
            } as Void
            availabilityStatus = "Opgeslagen"
        } catch {
            availabilityStatus = error.localizedDescription
        }
    }

    func reportSick(reason: String?) async {
        guard let config else { return }
        loading = true
        defer { loading = false }

        do {
            _ = try await authorized {
                try await api.sick(baseUrl: config.baseUrl, token: self.config?.accessToken, reason: reason)
            } as Void
            availabilityStatus = "Ziekmelding verzonden"
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendChat(_ text: String) async {
        guard let config else { return }
        do {
            let message = try await authorized {
                try await api.sendChat(baseUrl: config.baseUrl, token: self.config?.accessToken, text: text)
            }
            mergeChat(message)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func ensureChatConnected() {
        guard currentDest == .chat else {
            chatTask?.cancel()
            return
        }
        guard chatTask == nil || chatTask?.isCancelled == true else { return }
        guard let config else { return }

        chatTask = Task { [weak self] in
            guard let self else { return }
            do {
                let history = try await self.authorized {
                    try await self.api.chatHistory(baseUrl: config.baseUrl, token: self.config?.accessToken)
                }
                self.chatMessages = history
            } catch {
                self.error = error.localizedDescription
            }

            while !Task.isCancelled && self.currentDest == .chat {
                let lastId = self.chatMessages.last?.id ?? 0
                await self.api.streamChat(baseUrl: config.baseUrl, token: self.config?.accessToken, lastId: lastId) { [weak self] message in
                    Task { @MainActor in
                        self?.mergeChat(message)
                    }
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func destinationChanged(_ dest: Dest) {
        currentDest = dest
        if dest == .chat {
            ensureChatConnected()
        } else {
            chatTask?.cancel()
            chatTask = nil
        }

        if dest == .notifications {
            Task { await loadNotifications() }
        }

        if dest == .availability {
            Task { await loadAvailability(for: monthString(from: selectedMonth)) }
        }
    }

    func monthString(from date: Date) -> String {
        DateFormatter.yearMonth.string(from: date)
    }

    func allAvailable() {
        for key in availabilityEntries.keys {
            if var item = availabilityEntries[key] {
                item.isAvailable = true
                item.shiftPreference = nil
                availabilityEntries[key] = item
            }
        }
    }

    private func loadSessionData() async {
        loading = true
        error = nil
        defer { loading = false }

        guard let config else { return }

        do {
            me = try await authorized {
                try await api.me(baseUrl: config.baseUrl, token: self.config?.accessToken)
            }

            await refreshSchedules(daysAhead: 30)

            if let location = me?.locations.first {
                shifts = try await authorized {
                    try await api.shifts(baseUrl: config.baseUrl, token: self.config?.accessToken, locationId: location.id)
                }
            }
        } catch {
            self.error = "Sessie verlopen, log opnieuw in."
            clearSession()
        }
    }

    private func authorized<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch APIError.unauthorized {
            try await refreshAccessToken()
            return try await operation()
        }
    }

    private func refreshAccessToken() async throws {
        guard var cfg = config, let refreshToken = cfg.refreshToken else {
            throw APIError.unauthorized
        }

        let response = try await api.refresh(
            baseUrl: cfg.baseUrl,
            body: RefreshRequest(
                refreshToken: refreshToken,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        )

        cfg.accessToken = response.accessToken
        cfg.refreshToken = response.refreshToken
        config = cfg
        storage.saveConfig(cfg)
    }

    private func clearSession() {
        config = nil
        me = nil
        schedules = []
        notifications = []
        chatMessages = []
        shifts = []
        availabilityEntries = [:]
        storage.clear()
        error = nil
        loading = false
    }

    private func mergeChat(_ message: ChatMessage) {
        if !chatMessages.contains(where: { $0.id == message.id }) {
            chatMessages.append(message)
            chatMessages.sort { $0.id < $1.id }
        }
    }

    private func buildMonthDefaults(monthString: String) -> [String: AvailabilityEntryRequest] {
        let formatter = DateFormatter.yearMonth
        guard let date = formatter.date(from: monthString) else { return [:] }
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return [:] }

        var result: [String: AvailabilityEntryRequest] = [:]
        let components = calendar.dateComponents([.year, .month], from: date)

        for day in range {
            var dc = DateComponents()
            dc.year = components.year
            dc.month = components.month
            dc.day = day
            if let fullDate = calendar.date(from: dc) {
                let key = DateFormatter.isoDate.string(from: fullDate)
                result[key] = AvailabilityEntryRequest(date: key, isAvailable: true, shiftPreference: nil, customStart: nil, customEnd: nil, notes: nil)
            }
        }

        return result
    }
}

private extension DateFormatter {
    static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let yearMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
