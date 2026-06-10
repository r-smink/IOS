import Foundation

extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? decode(String.self, forKey: key),
                  let intValue = Int(stringValue) {
            return intValue
        }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected Int or String convertible to Int"))
    }

    func decodeFlexibleIntIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? decode(String.self, forKey: key),
                  let intValue = Int(stringValue) {
            return intValue
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

    enum CodingKeys: String, CodingKey {
        case id, workDate, startTime, endTime, status, notes, isSwappable
        case actualStartTime, actualEndTime, breakMinutes, shiftId, shiftName, color, locationId, locationName
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
    }
}

struct AvailabilityResponse: Codable {
    let locationId: Int
    let month: String
    let items: [AvailabilityItem]

    enum CodingKeys: String, CodingKey {
        case locationId, month, items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locationId = try container.decodeFlexibleInt(forKey: .locationId)
        month = try container.decode(String.self, forKey: .month)
        items = try container.decode([AvailabilityItem].self, forKey: .items)
    }
}

struct AvailabilityItem: Codable, Identifiable {
    let id: Int
    let workDate: String
    let isAvailable: Int
    let shiftPreference: Int?
    let customStart: String?
    let customEnd: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, workDate, isAvailable, shiftPreference, customStart, customEnd, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        workDate = try container.decode(String.self, forKey: .workDate)
        isAvailable = try container.decodeFlexibleInt(forKey: .isAvailable)
        shiftPreference = try container.decodeFlexibleIntIfPresent(forKey: .shiftPreference)
        customStart = try container.decodeIfPresent(String.self, forKey: .customStart)
        customEnd = try container.decodeIfPresent(String.self, forKey: .customEnd)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
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
    let locationId: Int
    let entries: [AvailabilityEntryRequest]
}

struct SickReportRequest: Codable {
    let reason: String?
}

struct APIErrorResponse: Codable {
    let code: String?
    let message: String?
}

struct DeviceRegistrationRequest: Codable {
    let fcmToken: String
    let platform: String
}
