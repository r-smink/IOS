import Foundation
import UIKit
import FirebaseMessaging

@MainActor
final class AppViewModel: ObservableObject {
    enum ScheduleFilter: String, CaseIterable, Identifiable {
        case personal = "Mijn rooster"
        case full = "Volledig rooster"
        var id: String { rawValue }
    }

    enum Dest: String, CaseIterable, Identifiable {
        case dashboard
        case schedule
        case availability
        case swaps
        case timeoff
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
            case .swaps: return "Ruilen"
            case .timeoff: return "Verlof"
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
            case .availability: return "checkmark.circle"
            case .swaps: return "arrow.2.squarepath"
            case .timeoff: return "beach.umbrella"
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
    @Published var fullSchedules: [ScheduleItem] = []
    @Published var monthStatus: MonthStatusResponse?
    @Published var scheduleFilter: ScheduleFilter = .personal
    @Published var selectedScheduleLocationId: Int?
    @Published var notifications: [NotificationItem] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var shifts: [Shift] = []
    @Published var availabilityEntries: [String: AvailabilityEntryRequest] = [:]
    @Published var availabilitySubmittedDates: Set<String> = []
    @Published var availabilityStatus: String?
    @Published var loading = false
    @Published var error: String?
    @Published var currentDest: Dest = .dashboard
    @Published var selectedMonth: Date = Date()
    @Published var teamPhoneContacts: [TeamPhoneContact] = []
    @Published var swapMyShifts: [SwapShift] = []
    @Published var swapAvailable: [SwapShift] = []
    @Published var swapIncoming: [SwapRequestItem] = []
    @Published var swapMine: [SwapRequestItem] = []
    @Published var swapColleagues: [Colleague] = []
    @Published var swapStatus: String?
    @Published var timeoffItems: [TimeoffItem] = []
    @Published var timeoffStatus: String?

    private let storage = Storage()
    private let api = APIClient()
    private var chatTask: Task<Void, Never>?
    private var pendingFCMToken: String?

    var nextShift: ScheduleItem? {
        let today = DateFormatter.isoDate.string(from: Date())
        return schedules.first { $0.workDate >= today }
    }

    var locationId: Int {
        me?.locations?.first?.id ?? 0
    }

    var hasLocations: Bool {
        !(me?.locations?.isEmpty ?? true)
    }

    var currentUserId: Int {
        me?.user?.id ?? 0
    }

    func bootstrap() async {
        config = storage.loadConfig()
        guard config != nil else { return }
        await loadSessionData()
    }

    private let defaultBaseUrl = "https://servawerkroosters.nl"

    func login(username: String, password: String) async {
        loading = true
        error = nil
        defer { loading = false }

        do {
            let response = try await api.login(
                baseUrl: defaultBaseUrl,
                body: LoginRequest(
                    username: username,
                    password: password,
                    deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "simulator-\(UUID().uuidString)"
                )
            )
            let newConfig = AuthConfig(
                baseUrl: defaultBaseUrl,
                username: username,
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            config = newConfig
            storage.saveConfig(newConfig)
            await loadSessionData()
        } catch let apiErr as APIError {
            self.error = "Inloggen mislukt: \(apiErr.localizedDescription)"
            print("[DEBUG] Login APIError: \(apiErr)")
        } catch {
            self.error = "Inloggen mislukt: \(error.localizedDescription)"
            print("[DEBUG] Login error: \(error)")
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

    func loadMonthStatus(month: String) async {
        guard let config else { return }
        do {
            monthStatus = try await authorized {
                try await api.monthStatus(baseUrl: config.baseUrl, token: self.config?.accessToken, month: month, locationId: selectedScheduleLocationId)
            }
        } catch {
            monthStatus = nil
            self.error = error.localizedDescription
        }
    }

    func loadFullSchedules(month: String) async {
        guard let config, let start = month.toMonthStart, let end = month.toMonthEnd else { return }
        do {
            fullSchedules = try await authorized {
                try await api.fullSchedules(baseUrl: config.baseUrl, token: self.config?.accessToken, startDate: start, endDate: end, locationId: selectedScheduleLocationId)
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
        guard let config, hasLocations else { return }
        loading = true
        availabilityStatus = nil
        defer { loading = false }

        do {
            // locationId = nil → server aggregates across all assigned locations
            let response = try await authorized {
                try await api.availability(baseUrl: config.baseUrl, token: self.config?.accessToken, month: monthString, locationId: nil)
            }

            var map = buildMonthDefaults(monthString: monthString)
            var submitted: Set<String> = []
            for item in response.items {
                map[item.workDate] = AvailabilityEntryRequest(
                    date: item.workDate,
                    isAvailable: item.isAvailable == 1,
                    shiftPreference: item.shiftPreference,
                    customStart: item.customStart,
                    customEnd: item.customEnd,
                    notes: item.notes
                )
                if let submittedAt = item.submittedAt, !submittedAt.isEmpty {
                    submitted.insert(item.workDate)
                }
            }
            availabilityEntries = map
            availabilitySubmittedDates = submitted

            // Use shifts from the aggregated response (covers all assigned locations)
            if let responseShifts = response.shifts, !responseShifts.isEmpty {
                shifts = responseShifts.map { s in
                    Shift(id: s.id, locationId: s.locationId, name: s.name, startTime: s.startTime, endTime: s.endTime, color: s.color)
                }
            }
        } catch {
            availabilityStatus = "Kon beschikbaarheid niet laden"
        }
    }

    func saveAvailability() async {
        guard let config, hasLocations else { return }
        loading = true
        defer { loading = false }

        do {
            // locationId = nil → server writes to all assigned locations
            let body = AvailabilityUpsertRequest(locationId: nil, entries: Array(availabilityEntries.values))
            _ = try await authorized {
                try await api.upsertAvailability(baseUrl: config.baseUrl, token: self.config?.accessToken, body: body)
            } as Void
            availabilitySubmittedDates = Set(availabilityEntries.keys)
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
            print("[DEBUG] Send chat error: \(error)")
            // Chat errors niet als alert tonen
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
                print("[DEBUG] Chat history error: \(error)")
            }

            var sseFailed = false
            while !Task.isCancelled && self.currentDest == .chat {
                let lastId = self.chatMessages.last?.id ?? 0
                if sseFailed {
                    // Fallback: poll via HTTP every 5 seconds
                    do {
                        let newMessages = try await self.authorized {
                            try await self.api.chatHistory(baseUrl: config.baseUrl, token: self.config?.accessToken, lastId: lastId)
                        }
                        for msg in newMessages {
                            self.mergeChat(msg)
                        }
                    } catch {
                        print("[DEBUG] Chat poll error: \(error)")
                    }
                    try? await Task.sleep(for: .seconds(5))
                } else {
                    // Try SSE stream
                    let startTime = Date()
                    await self.api.streamChat(baseUrl: config.baseUrl, token: self.config?.accessToken, lastId: lastId) { [weak self] message in
                        Task { @MainActor in
                            self?.mergeChat(message)
                        }
                    }
                    // If SSE returned almost immediately, it likely failed
                    if Date().timeIntervalSince(startTime) < 2 {
                        sseFailed = true
                        print("[DEBUG] SSE stream failed quickly, falling back to polling")
                    }
                    try? await Task.sleep(for: .seconds(3))
                }
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

        if dest == .swaps {
            Task { await loadSwapData() }
        }

        if dest == .timeoff {
            Task { await loadTimeoff() }
        }
    }

    func monthString(from date: Date) -> String {
        DateFormatter.yearMonth.string(from: date)
    }

    func registerFCMToken(_ token: String) async {
        guard let config else {
            pendingFCMToken = token
            print("[DEBUG] registerFCMToken: no config, saved as pending")
            return
        }
        do {
            _ = try await authorized {
                try await api.registerDevice(baseUrl: config.baseUrl, token: self.config?.accessToken, fcmToken: token)
            } as Void
            pendingFCMToken = nil
            print("[DEBUG] FCM token registered successfully")
        } catch {
            print("[DEBUG] FCM token registration failed: \(error)")
            pendingFCMToken = token
        }
    }

    func fetchTeamPhone() async {
        guard let config else { return }
        do {
            let response = try await authorized {
                try await api.teamPhone(baseUrl: config.baseUrl, token: self.config?.accessToken)
            }
            teamPhoneContacts = response.contacts
        } catch {
            print("[DEBUG] Team phone error: \(error)")
        }
    }

    func handleNotificationTap(type: String) {
        switch type {
        case "schedule", "shift":
            destinationChanged(.schedule)
        case "chat", "message":
            destinationChanged(.chat)
        case "availability":
            destinationChanged(.availability)
        default:
            destinationChanged(.notifications)
        }
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
            selectedScheduleLocationId = me?.locations?.first?.id
        } catch APIError.unauthorized {
            self.error = "Sessie verlopen, log opnieuw in."
            clearSession()
            return
        } catch {
            self.error = "Kon profiel niet laden: \(error.localizedDescription)"
            // Niet uitloggen - laat gebruiker de app in
        }

        // Schedules en shifts los laden - fouten hier loggen maar niet uitloggen
        await refreshSchedules(daysAhead: 30)

        // Fetch team phone numbers
        await fetchTeamPhone()

        // Register FCM token with backend (from UserDefaults or pending)
        let savedToken = pendingFCMToken ?? UserDefaults.standard.string(forKey: "fcm_token")
        if let fcmToken = savedToken {
            await registerFCMToken(fcmToken)
        }

        if let location = me?.locations?.first {
            do {
                shifts = try await authorized {
                    try await api.shifts(baseUrl: config.baseUrl, token: self.config?.accessToken, locationId: location.id)
                }
            } catch {
                self.error = error.localizedDescription
            }
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

    // MARK: - Shift swaps

    func loadSwapData() async {
        guard let config else { return }
        swapStatus = nil
        do {
            let my = try await authorized { try await api.swapsMyShifts(baseUrl: config.baseUrl, token: self.config?.accessToken) }
            swapMyShifts = my.shifts
            let avail = try await authorized { try await api.swapsAvailable(baseUrl: config.baseUrl, token: self.config?.accessToken) }
            swapAvailable = avail.shifts
            let reqs = try await authorized { try await api.swapsRequests(baseUrl: config.baseUrl, token: self.config?.accessToken) }
            swapIncoming = reqs.incoming
            swapMine = reqs.mine
            let cols = try await authorized { try await api.swapsColleagues(baseUrl: config.baseUrl, token: self.config?.accessToken) }
            swapColleagues = cols.colleagues
        } catch {
            swapStatus = "Kon ruilgegevens niet laden"
        }
    }

    func toggleSwappable(scheduleId: Int) async {
        guard let config else { return }
        do {
            let resp = try await authorized {
                try await api.toggleSwappable(baseUrl: config.baseUrl, token: self.config?.accessToken, scheduleId: scheduleId)
            }
            swapStatus = resp.message
            await loadSwapData()
        } catch {
            swapStatus = "Kon ruilbaar-status niet wijzigen"
        }
    }

    func requestSwap(scheduleId: Int, colleagueId: Int?, reason: String?) async {
        guard let config else { return }
        do {
            _ = try await authorized {
                try await api.requestSwap(baseUrl: config.baseUrl, token: self.config?.accessToken, body: RequestSwapBody(scheduleId: scheduleId, requestedEmployeeId: colleagueId, reason: reason))
            } as Void
            swapStatus = "Ruilverzoek ingediend"
            await loadSwapData()
        } catch {
            swapStatus = "Ruilverzoek indienen mislukt"
        }
    }

    func respondSwap(swapId: Int, action: String) async {
        guard let config else { return }
        do {
            _ = try await authorized {
                try await api.respondSwap(baseUrl: config.baseUrl, token: self.config?.accessToken, swapId: swapId, action: action)
            } as Void
            swapStatus = action == "accept" ? "Verzoek geaccepteerd" : "Verzoek afgewezen"
            await loadSwapData()
        } catch {
            swapStatus = "Kon niet reageren op verzoek"
        }
    }

    func claimShift(scheduleId: Int) async {
        guard let config else { return }
        do {
            _ = try await authorized {
                try await api.claimSwap(baseUrl: config.baseUrl, token: self.config?.accessToken, scheduleId: scheduleId)
            } as Void
            swapStatus = "Dienst overgenomen"
            await loadSwapData()
        } catch {
            swapStatus = "Dienst overnemen mislukt"
        }
    }

    // MARK: - Time off (verlof)

    func loadTimeoff() async {
        guard let config else { return }
        timeoffStatus = nil
        do {
            let resp = try await authorized {
                try await api.timeoff(baseUrl: config.baseUrl, token: self.config?.accessToken)
            }
            timeoffItems = resp.items
        } catch {
            timeoffStatus = "Kon verlofaanvragen niet laden"
        }
    }

    func submitTimeoff(startDate: String, endDate: String, type: String, reason: String?) async {
        guard let config else { return }
        do {
            _ = try await authorized {
                try await api.submitTimeoff(baseUrl: config.baseUrl, token: self.config?.accessToken, body: TimeoffRequestBody(startDate: startDate, endDate: endDate, type: type, reason: reason))
            } as Void
            timeoffStatus = "Aanvraag verzonden!"
            await loadTimeoff()
        } catch {
            timeoffStatus = "Aanvraag indienen mislukt"
        }
    }

    private func clearSession() {
        config = nil
        me = nil
        schedules = []
        notifications = []
        chatMessages = []
        shifts = []
        availabilityEntries = [:]
        availabilitySubmittedDates = []
        teamPhoneContacts = []
        swapMyShifts = []
        swapAvailable = []
        swapIncoming = []
        swapMine = []
        swapColleagues = []
        swapStatus = nil
        timeoffItems = []
        timeoffStatus = nil
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
