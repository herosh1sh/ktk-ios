import Foundation

/// Manages UserDefaults for app settings and lightweight persistence
public final class UserDefaultsManager {
    public static let shared = UserDefaultsManager()

    private let defaults = UserDefaults.standard
    private let suiteName = "ru.ktk.education-system.app"

    private init() {}

    // MARK: - Login State

    public var isLoggedIn: Bool {
        get { defaults.bool(forKey: AppConfiguration.UserDefaultsKeys.isLoggedIn) }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.isLoggedIn) }
    }

    public var lastLogin: Date? {
        get { defaults.object(forKey: AppConfiguration.UserDefaultsKeys.lastLogin) as? Date }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.lastLogin) }
    }

    public var savedCollegeId: String? {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.savedCollegeId) }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.savedCollegeId) }
    }

    // MARK: - User Profile

    public var sessionId: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.sessionId) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.sessionId) }
    }

    public var userGroup: Int {
        get { defaults.integer(forKey: AppConfiguration.UserDefaultsKeys.userGroup) }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.userGroup) }
    }

    public var userSubgroup: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.userSubgroup) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.userSubgroup) }
    }

    public var userBranch: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.userBranch) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.userBranch) }
    }

    public var isTeacher: Bool {
        get { defaults.bool(forKey: AppConfiguration.UserDefaultsKeys.isTeacher) }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.isTeacher) }
    }

    public var teacherHash: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.teacherHash) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.teacherHash) }
    }

    // MARK: - Discovered Endpoints

    public var personalEndpoint: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.personalEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.personalEndpoint) }
    }

    public var groupEndpoint: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.groupEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.groupEndpoint) }
    }

    public var branch: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.branch) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.branch) }
    }

    public var callsEndpoint: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.callsEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.callsEndpoint) }
    }

    public var typesEndpoint: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.typesEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.typesEndpoint) }
    }

    public var absenceEndpoint: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.absenceEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.absenceEndpoint) }
    }

    public var fileHashEndpoint: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.fileHashEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.fileHashEndpoint) }
    }

    public var homeworkHashEndpoint: String {
        get { defaults.string(forKey: AppConfiguration.UserDefaultsKeys.homeworkHashEndpoint) ?? "" }
        set { defaults.set(newValue, forKey: AppConfiguration.UserDefaultsKeys.homeworkHashEndpoint) }
    }

    // MARK: - App Settings

    public var selectedWeekOffset: Int {
        get { defaults.integer(forKey: "ktk.selectedWeekOffset") }
        set { defaults.set(newValue, forKey: "ktk.selectedWeekOffset") }
    }

    public var showSubgroupOnly: Bool {
        get { defaults.bool(forKey: "ktk.showSubgroupOnly") }
        set { defaults.set(newValue, forKey: "ktk.showSubgroupOnly") }
    }

    public var notificationsEnabled: Bool {
        get { defaults.bool(forKey: "ktk.notificationsEnabled") }
        set { defaults.set(newValue, forKey: "ktk.notificationsEnabled") }
    }

    public var autoRefreshEnabled: Bool {
        get { defaults.bool(forKey: "ktk.autoRefreshEnabled") }
        set { defaults.set(newValue, forKey: "ktk.autoRefreshEnabled") }
    }

    public var themeMode: String {
        get { defaults.string(forKey: "ktk.themeMode") ?? "system" }
        set { defaults.set(newValue, forKey: "ktk.themeMode") }
    }

    // MARK: - Cache

    public func saveScheduleCache(_ schedule: [ScheduleDay], forWeek week: Week, scope: String) {
        let key = "schedule_\(scope)_\(week.millis)"
        if let data = try? JSONEncoder().encode(schedule) {
            defaults.set(data, forKey: key)
            // Also save timestamp
            defaults.set(Date(), forKey: "\(key)_timestamp")
        }
    }

    public func loadScheduleCache(forWeek week: Week, scope: String, maxAge: TimeInterval = 3600) -> [ScheduleDay]? {
        let key = "schedule_\(scope)_\(week.millis)"
        guard let data = defaults.data(forKey: key),
              let timestamp = defaults.object(forKey: "\(key)_timestamp") as? Date,
              Date().timeIntervalSince(timestamp) < maxAge else {
            return nil
        }
        return try? JSONDecoder().decode([ScheduleDay].self, from: data)
    }

    public func clearScheduleCache() {
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("schedule_") }
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - Reference Data Cache

    public func saveReferenceData(_ data: ReferenceData) {
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: "ktk.referenceData")
            defaults.set(Date(), forKey: "ktk.referenceData_timestamp")
        }
    }

    public func loadReferenceData(maxAge: TimeInterval = 86400) -> ReferenceData? {
        guard let data = defaults.data(forKey: "ktk.referenceData"),
              let timestamp = defaults.object(forKey: "ktk.referenceData_timestamp") as? Date,
              Date().timeIntervalSince(timestamp) < maxAge else {
            return nil
        }
        return try? JSONDecoder().decode(ReferenceData.self, from: data)
    }

    // MARK: - Reset

    public func clearLoginState() {
        let keys = [
            AppConfiguration.UserDefaultsKeys.isLoggedIn,
            AppConfiguration.UserDefaultsKeys.lastLogin,
            AppConfiguration.UserDefaultsKeys.sessionId,
            AppConfiguration.UserDefaultsKeys.userGroup,
            AppConfiguration.UserDefaultsKeys.userSubgroup,
            AppConfiguration.UserDefaultsKeys.userBranch,
            AppConfiguration.UserDefaultsKeys.isTeacher,
            AppConfiguration.UserDefaultsKeys.teacherHash,
            AppConfiguration.UserDefaultsKeys.personalEndpoint,
            AppConfiguration.UserDefaultsKeys.groupEndpoint,
            AppConfiguration.UserDefaultsKeys.branch,
            AppConfiguration.UserDefaultsKeys.callsEndpoint,
            AppConfiguration.UserDefaultsKeys.typesEndpoint,
            AppConfiguration.UserDefaultsKeys.absenceEndpoint,
            AppConfiguration.UserDefaultsKeys.fileHashEndpoint,
            AppConfiguration.UserDefaultsKeys.homeworkHashEndpoint
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    public func clearAll() {
        let appKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("ktk.") }
        appKeys.forEach { defaults.removeObject(forKey: $0) }
    }
}