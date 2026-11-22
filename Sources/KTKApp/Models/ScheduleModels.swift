import Foundation

// MARK: - Login Models

/// Login request payload
public struct LoginRequest: Codable {
    public let collegeId: String
    public let password: String
    public let fingerprint: String

    public init(collegeId: String, password: String, fingerprint: String) {
        self.collegeId = collegeId
        self.password = password
        self.fingerprint = fingerprint
    }
}

/// Login response from the server
public struct LoginResponse: Codable {
    public let user: UserInfo
    public let session: SessionInfo?
    public let error: APIError?

    public var isSuccess: Bool {
        return error == nil && !user.collegeId.isEmpty
    }
}

public struct UserInfo: Codable {
    public let collegeId: String
    public let isStudent: Bool
    public let group: GroupInfo?
    public let branch: String?
    public let hash: String? // For teachers
    public let session: SessionInfo?
    public let subgroup: String?

    enum CodingKeys: String, CodingKey {
        case collegeId = "collegeId"
        case isStudent = "isStudent"
        case group = "group"
        case branch = "branch"
        case hash = "hash"
        case session = "session"
        case subgroup = "subgroup"
    }
}

public struct GroupInfo: Codable {
    public let id: Int
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
    }
}

public struct SessionInfo: Codable {
    public let id: String

    enum CodingKeys: String, CodingKey {
        case id = "id"
    }
}

public struct APIError: Codable {
    public let appError: AppErrorDetail?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case appError = "appError"
        case message = "message"
    }
}

public struct AppErrorDetail: Codable {
    public let code: String?
    public let type: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case code = "code"
        case type = "type"
        case message = "message"
    }
}

// MARK: - Schedule Models

/// Represents a day in the schedule
public struct ScheduleDay: Codable, Identifiable, Hashable {
    public let id = UUID()
    public let callPreset: Int
    public let date: String
    public let today: Bool
    public let maxPair: Int
    public let subjects: [Subject]

    enum CodingKeys: String, CodingKey {
        case callPreset = "callPreset"
        case date = "date"
        case today = "today"
        case maxPair = "maxPair"
        case subjects = "subjects"
    }

    public var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.date(from: date)
    }

    public var dayOfWeek: String {
        guard let date = parsedDate else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized
    }

    public var formattedDate: String {
        guard let date = parsedDate else { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

/// Represents a subject/lesson in the schedule
public struct Subject: Codable, Identifiable, Hashable {
    public let id = UUID()
    public let appraisal: Int
    public let discipline: String
    public let lectureHall: Int
    public let mark: Int
    public let pair: Int
    public let subgroup: String
    public let teacher: String
    public let group: String
    public let callPreset: Int
    public let extendedData: ExtendedData
    public let extraData: ExtraData

    enum CodingKeys: String, CodingKey {
        case appraisal = "appraisal"
        case discipline = "discipline"
        case lectureHall = "lectureHall"
        case mark = "mark"
        case pair = "pair"
        case subgroup = "subgroup"
        case teacher = "teacher"
        case group = "group"
        case callPreset = "callPreset"
        case extendedData = "extendedData"
        case extraData = "extraData"
    }

    public var timeRange: String {
        // Will be populated from call presets
        return ""
    }

    public var location: String {
        if lectureHall > 0 {
            return "Ауд. \(lectureHall)"
        }
        return "—"
    }
}

/// Extended data for a subject
public struct ExtendedData: Codable, Hashable {
    public let hasHomework: Bool
    public let remote: Bool
    public let webinar: Bool

    enum CodingKeys: String, CodingKey {
        case hasHomework = "hasHomework"
        case remote = "remote"
        case webinar = "webinar"
    }
}

/// Extra data for a subject (homework, files, etc.)
public struct ExtraData: Codable, Hashable {
    public let sheet: Int
    public var homework: HomeworkData?

    enum CodingKeys: String, CodingKey {
        case sheet = "sheet"
        case homework = "homework"
    }
}

/// Homework/task data for a lesson
public struct HomeworkData: Codable, Hashable {
    public let text: String?
    public let deadline: String?
    public var files: [HomeworkFile]?
    public var webinar: WebinarLink?

    enum CodingKeys: String, CodingKey {
        case text = "text"
        case deadline = "deadline"
        case files = "files"
        case webinar = "webinar"
    }
}

/// File attached to homework
public struct HomeworkFile: Codable, Hashable, Identifiable {
    public let id = UUID()
    public let caption: String
    public let extension: String
    public let journal: Int
    public let weekStart: String
    public let group: String?

    enum CodingKeys: String, CodingKey {
        case caption = "caption"
        case extension = "extension"
        case journal = "journal"
        case weekStart = "weekStart"
        case group = "group"
    }

    public var fileExtension: String {
        return `extension`
    }
}

/// Webinar link for remote lessons
public struct WebinarLink: Codable, Hashable {
    public let url: String
    public let title: String?

    enum CodingKeys: String, CodingKey {
        case url = "url"
        case title = "title"
    }
}

// MARK: - Reference Data Models

/// Call preset (time schedule)
public struct CallPreset: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let pairs: [CallPair]

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case pairs = "pairs"
    }
}

public struct CallPair: Codable, Hashable {
    public let number: Int
    public let startTime: String
    public let endTime: String

    enum CodingKeys: String, CodingKey {
        case number = "number"
        case startTime = "startTime"
        case endTime = "endTime"
    }
}

/// Pair type (lecture, practice, lab, etc.)
public struct PairType: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let shortName: String
    public let color: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case shortName = "shortName"
        case color = "color"
    }
}

/// Lecture hall
public struct LectureHall: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let building: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case building = "building"
    }
}

/// Reference data container
public struct ReferenceData: Codable, Hashable {
    public let calls: [CallPreset]
    public let types: [PairType]
    public let halls: [LectureHall]
}

// MARK: - Week Models

/// Academic week representation
public struct Week: Codable, Hashable, Identifiable {
    public let id = UUID()
    public let start: Date
    public let end: Date
    public let number: Int
    public let academicYear: Int

    public var millis: Int64 {
        return Int64(start.timeIntervalSince1970 * 1000)
    }

    public var formattedRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    public static func current() -> Week {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
        let weekOfYear = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return Week(start: startOfWeek, end: endOfWeek, number: weekOfYear, academicYear: year)
    }

    public static func week(for date: Date) -> Week {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return Week(start: startOfWeek, end: endOfWeek, number: weekOfYear, academicYear: year)
    }

    public func nextWeek() -> Week {
        let calendar = Calendar.current
        let nextStart = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return Week.week(for: nextStart)
    }

    public func previousWeek() -> Week {
        let calendar = Calendar.current
        let prevStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start
        return Week.week(for: prevStart)
    }
}

// MARK: - API Response Wrappers

/// Generic API response wrapper for server functions
public struct ServerFunctionResponse<T: Codable>: Codable {
    public let data: T?
    public let error: APIError?

    public var isSuccess: Bool {
        return error == nil && data != nil
    }
}

/// Schedule response (can be array of days or wrapped)
public typealias ScheduleResponse = [ScheduleDay]

// MARK: - Helper Extensions

extension Array where Element == ScheduleDay {
    public func groupedByDate() -> [(date: Date, days: [ScheduleDay])] {
        let grouped = Dictionary(grouping: self) { day in
            day.parsedDate ?? Date.distantPast
        }
        return grouped.sorted { $0.key < $1.key }
            .map { (date: $0.key, days: $0.value.sorted { $0.pair < $1.pair }) }
    }

    public func subjectsForPair(_ pair: Int, subgroup: String) -> [Subject] {
        return self.flatMap { day in
            day.subjects.filter { $0.pair == pair && ($0.subgroup.isEmpty || $0.subgroup == subgroup) }
        }
    }
}