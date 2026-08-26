import Foundation

extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? decode(String.self, forKey: key),
                  let intValue = Int(stringValue) {
            return intValue
        } else if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue ? 1 : 0
        }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected Int or String convertible to Int"))
    }

    func decodeFlexibleIntIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? decode(String.self, forKey: key),
                  let intValue = Int(stringValue) {
            return intValue
        } else if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue ? 1 : 0
        }
        return nil
    }
}

struct AuthConfig: Codable {
    var baseUrl: String
    var username: String
    var accessToken: String?
    var refreshToken: String?
}

struct LoginRequest: Codable {
    let username: String
    let password: String
    let deviceId: String?
}

struct LoginResponse: Codable {
    let accessToken: String
    let accessExpiresIn: Int
    let refreshToken: String
    let refreshExpiresIn: Int
    let userId: Int

    enum CodingKeys: String, CodingKey {
        case accessToken, accessExpiresIn, refreshToken, refreshExpiresIn, userId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        accessExpiresIn = try container.decode(Int.self, forKey: .accessExpiresIn)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        refreshExpiresIn = try container.decode(Int.self, forKey: .refreshExpiresIn)
        // Handle userId as either Int or String
        if let intValue = try? container.decode(Int.self, forKey: .userId) {
            userId = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .userId),
                  let intValue = Int(stringValue) {
            userId = intValue
        } else {
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: [CodingKeys.userId], debugDescription: "userId must be Int or String"))
        }
    }
}

struct RefreshRequest: Codable {
    let refreshToken: String
    let deviceId: String?
}

struct LogoutRequest: Codable {
    let refreshToken: String
}

struct MeResponse: Codable {
    let user: User?
    let employee: Employee?
    let locations: [Location]?
    let icalUrl: String?
}

struct User: Codable {
    let id: Int
    let displayName: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id, displayName, email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decode(String.self, forKey: .email)
    }
}

struct Employee: Codable {
    let id: Int
    let isAdmin: Bool
    let isFixed: Bool
    let themePreference: String?
    let emailNotifications: Bool
    let pushNotifications: Bool

    enum CodingKeys: String, CodingKey {
        case id, isAdmin, isFixed, themePreference, emailNotifications, pushNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        isFixed = try container.decode(Bool.self, forKey: .isFixed)
        themePreference = try container.decodeIfPresent(String.self, forKey: .themePreference)
        emailNotifications = try container.decode(Bool.self, forKey: .emailNotifications)
        pushNotifications = try container.decode(Bool.self, forKey: .pushNotifications)
    }
}

struct Location: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let address: String?

    enum CodingKeys: String, CodingKey {
        case id, name, address
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
    }
}

struct ScheduleItem: Codable, Identifiable, Hashable {
    let id: Int
    let workDate: String
    let startTime: String?
    let endTime: String?
    let status: String
    let notes: String?
    let isSwappable: Int
    let actualStartTime: String?
    let actualEndTime: String?
    let breakMinutes: Int?
    let shiftId: Int?
    let shiftName: String?
    let color: String?
    let locationId: Int?
    let locationName: String?
    let employeeId: Int?
    let employeeName: String?
    let shiftStartTime: String?
    let shiftEndTime: String?

    enum CodingKeys: String, CodingKey {
        case id, workDate, startTime, endTime, status, notes, isSwappable
        case actualStartTime, actualEndTime, breakMinutes, shiftId, shiftName, color, locationId, locationName
        case employeeId, employeeName, shiftStartTime, shiftEndTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        workDate = try container.decode(String.self, forKey: .workDate)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        status = try container.decode(String.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isSwappable = try container.decodeFlexibleInt(forKey: .isSwappable)
        actualStartTime = try container.decodeIfPresent(String.self, forKey: .actualStartTime)
        actualEndTime = try container.decodeIfPresent(String.self, forKey: .actualEndTime)
        breakMinutes = try container.decodeFlexibleIntIfPresent(forKey: .breakMinutes)
        shiftId = try container.decodeFlexibleIntIfPresent(forKey: .shiftId)
        shiftName = try container.decodeIfPresent(String.self, forKey: .shiftName)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        locationId = try container.decodeFlexibleIntIfPresent(forKey: .locationId)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        employeeId = try container.decodeFlexibleIntIfPresent(forKey: .employeeId)
        employeeName = try container.decodeIfPresent(String.self, forKey: .employeeName)
        shiftStartTime = try container.decodeIfPresent(String.self, forKey: .shiftStartTime)
        shiftEndTime = try container.decodeIfPresent(String.self, forKey: .shiftEndTime)
    }
}

struct AvailabilityResponse: Codable {
    let locationId: Int
    let locationIds: [Int]?
    let month: String
    let items: [AvailabilityItem]
    let shifts: [AvailabilityShift]?

    enum CodingKeys: String, CodingKey {
        case locationId, locationIds, month, items, shifts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locationId = try container.decodeFlexibleInt(forKey: .locationId)
        locationIds = try? container.decode([Int].self, forKey: .locationIds)
        month = try container.decode(String.self, forKey: .month)
        items = try container.decode([AvailabilityItem].self, forKey: .items)
        shifts = try? container.decode([AvailabilityShift].self, forKey: .shifts)
    }
}

struct AvailabilityShift: Codable, Identifiable, Hashable {
    let id: Int
    let locationId: Int?
    let name: String
    let startTime: String?
    let endTime: String?
    let color: String?
    let locationName: String?

    enum CodingKeys: String, CodingKey {
        case id, locationId, name, startTime, endTime, color, locationName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        locationId = try container.decodeFlexibleIntIfPresent(forKey: .locationId)
        name = try container.decode(String.self, forKey: .name)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
    }
}

struct AvailabilityItem: Codable, Identifiable {
    let id: Int
    let workDate: String
    let isAvailable: Int
    let isAllDay: Int?
    let shiftPreference: Int?
    let customStart: String?
    let customEnd: String?
    let notes: String?
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, workDate, isAvailable, isAllDay, shiftPreference, customStart, customEnd, notes, submittedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        workDate = try container.decode(String.self, forKey: .workDate)
        isAvailable = try container.decodeFlexibleInt(forKey: .isAvailable)
        isAllDay = try container.decodeFlexibleIntIfPresent(forKey: .isAllDay)
        shiftPreference = try container.decodeFlexibleIntIfPresent(forKey: .shiftPreference)
        customStart = try container.decodeIfPresent(String.self, forKey: .customStart)
        customEnd = try container.decodeIfPresent(String.self, forKey: .customEnd)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        submittedAt = try container.decodeIfPresent(String.self, forKey: .submittedAt)
    }
}

struct NotificationItem: Codable, Identifiable, Hashable {
    let id: Int
    let type: String
    let title: String
    let message: String?
    let isRead: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, message, isRead, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        isRead = try container.decodeFlexibleInt(forKey: .isRead)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

struct Shift: Codable, Identifiable, Hashable {
    let id: Int
    let locationId: Int?
    let name: String
    let startTime: String?
    let endTime: String?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case id, locationId, name, startTime, endTime, color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        locationId = try container.decodeFlexibleIntIfPresent(forKey: .locationId)
        name = try container.decode(String.self, forKey: .name)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        color = try container.decodeIfPresent(String.self, forKey: .color)
    }

    init(id: Int, locationId: Int?, name: String, startTime: String?, endTime: String?, color: String?) {
        self.id = id
        self.locationId = locationId
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    let senderId: Int
    let senderName: String
    let message: String
    let isAnnouncement: Int
    let locationId: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, senderId, senderName, message, isAnnouncement, locationId, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        senderId = try container.decodeFlexibleInt(forKey: .senderId)
        senderName = try container.decode(String.self, forKey: .senderName)
        message = try container.decode(String.self, forKey: .message)
        isAnnouncement = try container.decodeFlexibleInt(forKey: .isAnnouncement)
        locationId = try container.decodeFlexibleIntIfPresent(forKey: .locationId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

struct SendMessageRequest: Codable {
    let message: String
    let locationId: Int?
    let isAnnouncement: Int
}

struct AvailabilityEntryRequest: Codable, Identifiable, Hashable {
    var id: String { date }
    let date: String
    var isAvailable: Bool
    var shiftPreference: Int?
    var customStart: String?
    var customEnd: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case date, isAvailable, shiftPreference, customStart, customEnd, notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(isAvailable ? 1 : 0, forKey: .isAvailable)
        try container.encodeIfPresent(shiftPreference, forKey: .shiftPreference)
        try container.encodeIfPresent(customStart, forKey: .customStart)
        try container.encodeIfPresent(customEnd, forKey: .customEnd)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        let availableInt = try container.decode(Int.self, forKey: .isAvailable)
        isAvailable = availableInt == 1
        shiftPreference = try container.decodeIfPresent(Int.self, forKey: .shiftPreference)
        customStart = try container.decodeIfPresent(String.self, forKey: .customStart)
        customEnd = try container.decodeIfPresent(String.self, forKey: .customEnd)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    init(date: String, isAvailable: Bool, shiftPreference: Int?, customStart: String?, customEnd: String?, notes: String?) {
        self.date = date
        self.isAvailable = isAvailable
        self.shiftPreference = shiftPreference
        self.customStart = customStart
        self.customEnd = customEnd
        self.notes = notes
    }
}

struct AvailabilityUpsertRequest: Codable {
    let locationId: Int?
    let entries: [AvailabilityEntryRequest]
}

struct SickReportRequest: Codable {
    let reason: String?
}

struct TeamPhoneContact: Codable, Identifiable {
    let name: String
    let phone: String
    var id: String { "\(name)-\(phone)" }
}

struct TeamPhoneResponse: Codable {
    let contacts: [TeamPhoneContact]
}

struct APIErrorResponse: Codable {
    let code: String?
    let message: String?
}

struct DeviceRegistrationRequest: Codable {
    let fcmToken: String
    let platform: String
}

// MARK: - Shift swap models

struct SwapShift: Codable, Identifiable, Hashable {
    let id: Int
    let workDate: String
    let startTime: String?
    let endTime: String?
    let status: String
    let isSwappable: Int
    let notes: String?
    let shiftName: String?
    let color: String?
    let locationId: Int?
    let locationName: String?
    let ownerName: String?

    enum CodingKeys: String, CodingKey {
        case id, workDate, startTime, endTime, status, isSwappable, notes, shiftName, color, locationId, locationName, ownerName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        workDate = try container.decode(String.self, forKey: .workDate)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        status = try container.decode(String.self, forKey: .status)
        isSwappable = try container.decodeFlexibleInt(forKey: .isSwappable)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        shiftName = try container.decodeIfPresent(String.self, forKey: .shiftName)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        locationId = try container.decodeFlexibleIntIfPresent(forKey: .locationId)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName)
    }
}

struct MyShiftsResponse: Codable { let shifts: [SwapShift] }
struct AvailableShiftsResponse: Codable { let shifts: [SwapShift] }

struct SwapRequestItem: Codable, Identifiable, Hashable {
    let id: Int
    let scheduleId: Int
    let reason: String?
    let status: String
    let requestedAt: String?
    let respondedAt: String?
    let workDate: String?
    let startTime: String?
    let endTime: String?
    let shiftName: String?
    let locationId: Int?
    let locationName: String?
    let requesterName: String?
    let requestedName: String?

    enum CodingKeys: String, CodingKey {
        case id, scheduleId, reason, status, requestedAt, respondedAt, workDate, startTime, endTime, shiftName, locationId, locationName, requesterName, requestedName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        scheduleId = try container.decodeFlexibleInt(forKey: .scheduleId)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        status = try container.decode(String.self, forKey: .status)
        requestedAt = try container.decodeIfPresent(String.self, forKey: .requestedAt)
        respondedAt = try container.decodeIfPresent(String.self, forKey: .respondedAt)
        workDate = try container.decodeIfPresent(String.self, forKey: .workDate)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        shiftName = try container.decodeIfPresent(String.self, forKey: .shiftName)
        locationId = try container.decodeFlexibleIntIfPresent(forKey: .locationId)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        requesterName = try container.decodeIfPresent(String.self, forKey: .requesterName)
        requestedName = try container.decodeIfPresent(String.self, forKey: .requestedName)
    }
}

struct SwapsRequestsResponse: Codable {
    let incoming: [SwapRequestItem]
    let mine: [SwapRequestItem]
}

struct Colleague: Codable, Identifiable, Hashable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
}

struct ColleaguesResponse: Codable { let colleagues: [Colleague] }

struct RequestSwapBody: Codable {
    let scheduleId: Int
    let requestedEmployeeId: Int?
    let reason: String?
}

struct RespondSwapBody: Codable {
    let action: String
}

struct ClaimSwapBody: Codable {
    let scheduleId: Int
}

struct ToggleSwappableResponse: Codable {
    let isSwappable: Int
    let message: String?
}

// MARK: - Full roster / month status

struct MonthStatusResponse: Codable {
    let isFinalized: Bool
    let finalizedAt: String?
    let finalizedBy: String?
    let locationId: Int?
    let month: String?

    enum CodingKeys: String, CodingKey {
        case isFinalized, finalizedAt, finalizedBy, locationId, month
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isFinalized = try container.decode(Bool.self, forKey: .isFinalized)
        finalizedAt = try container.decodeIfPresent(String.self, forKey: .finalizedAt)
        finalizedBy = try container.decodeIfPresent(String.self, forKey: .finalizedBy)
        locationId = try? container.decodeFlexibleIntIfPresent(forKey: .locationId)
        month = try container.decodeIfPresent(String.self, forKey: .month)
    }
}

struct TimeoffItem: Codable, Identifiable, Hashable {
    let id: Int
    let startDate: String
    let endDate: String
    let type: String
    let status: String
    let reason: String?
    let adminNotes: String?
    let requestedAt: String?
    let respondedAt: String?
    let daysRequested: Int?

    enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, type, status, reason, adminNotes, requestedAt, respondedAt, daysRequested
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        startDate = try container.decode(String.self, forKey: .startDate)
        endDate = try container.decode(String.self, forKey: .endDate)
        type = try container.decode(String.self, forKey: .type)
        status = try container.decode(String.self, forKey: .status)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        adminNotes = try container.decodeIfPresent(String.self, forKey: .adminNotes)
        requestedAt = try container.decodeIfPresent(String.self, forKey: .requestedAt)
        respondedAt = try container.decodeIfPresent(String.self, forKey: .respondedAt)
        daysRequested = try container.decodeFlexibleIntIfPresent(forKey: .daysRequested)
    }
}

struct TimeoffResponse: Codable {
    let items: [TimeoffItem]
}

struct TimeoffRequestBody: Codable {
    let startDate: String
    let endDate: String
    let type: String
    let reason: String?
}
