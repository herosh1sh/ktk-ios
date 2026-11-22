import Foundation

/// Persisted session record for restoring login state
/// Mirrors the Rust SessionRecord structure
public struct SessionRecord: Codable {
    public let cookie: String
    public let sessionId: String
    public let group: Int
    public let subgroup: String
    public let teacher: String
    public let branch: String
    public let personalEndpoint: String
    public let groupEndpoint: String

    public init(
        cookie: String,
        sessionId: String,
        group: Int,
        subgroup: String,
        teacher: String,
        branch: String,
        personalEndpoint: String,
        groupEndpoint: String
    ) {
        self.cookie = cookie
        self.sessionId = sessionId
        self.group = group
        self.subgroup = subgroup
        self.teacher = teacher
        self.branch = branch
        self.personalEndpoint = personalEndpoint
        self.groupEndpoint = groupEndpoint
    }

    /// Check if the session record has valid data
    public var isValid: Bool {
        return !cookie.isEmpty && (!sessionId.isEmpty || group > 0)
    }
}

/// Account credentials stored in keychain
public struct AccountCredentials: Codable {
    public let collegeId: String
    public let password: String // Note: In production, consider not storing password
    public let deviceIdentifier: String

    public init(collegeId: String, password: String, deviceIdentifier: String = AppConfiguration.deviceIdentifier) {
        self.collegeId = collegeId
        self.password = password
        self.deviceIdentifier = deviceIdentifier
    }
}

/// User profile information
public struct UserProfile: Codable {
    public let collegeId: String
    public let isStudent: Bool
    public let group: Int
    public let subgroup: String
    public let branch: String
    public let teacherHash: String
    public let sessionId: String

    public var displayName: String {
        if isStudent {
            return "Студент \(collegeId)"
        } else {
            return "Преподаватель \(collegeId)"
        }
    }

    public var groupDisplay: String {
        if isStudent {
            return subgroup.isEmpty ? "Группа \(group)" : "Группа \(group), подгруппа \(subgroup)"
        } else {
            return "Преподаватель"
        }
    }
}