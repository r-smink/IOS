import Foundation

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
}

struct Employee: Codable {
    let id: Int
    let isAdmin: Bool
    let isFixed: Bool
    let themePreference: String?
    let emailNotifications: Bool
    let pushNotifications: Bool
}

struct Location: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let address: String?
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
}

struct AvailabilityResponse: Codable {
    let locationId: Int
    let month: String
    let items: [AvailabilityItem]
}

struct AvailabilityItem: Codable, Identifiable {
    let id: Int
    let workDate: String
    let isAvailable: Int
    let shiftPreference: Int?
    let customStart: String?
    let customEnd: String?
    let notes: String?
}

struct NotificationItem: Codable, Identifiable, Hashable {
    let id: Int
    let type: String
    let title: String
    let message: String?
    let isRead: Int
    let createdAt: String
}

struct Shift: Codable, Identifiable, Hashable {
    let id: Int
    let locationId: Int?
    let name: String
    let startTime: String?
    let endTime: String?
    let color: String?
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    let senderId: Int
    let senderName: String
    let message: String
    let isAnnouncement: Int
    let locationId: Int?
    let createdAt: String
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
