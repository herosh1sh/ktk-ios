import Foundation

/// Central configuration for the KTK App
public enum AppConfiguration {
    /// Base URL for the KTK Education System API
    public static let baseURL = "https://ktk.education-system.ru"

    /// Default headers required by the API
    public static let defaultHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept": "application/x-tss-framed, application/x-ndjson, application/json",
        "x-tsr-serverfn": "true",
        "x-application-storage-mode": "ordinary",
        "sec-fetch-site": "same-origin",
        "sec-fetch-mode": "cors",
        "sec-fetch-dest": "empty"
    ]

    /// Known server function endpoints (may change on redeploy)
    /// These are the default endpoints from the Rust reference implementation
    public struct ServerFunctions {
        public static let signIn = "/_serverFn/9cd5b48fd0588913cb64c83d8ae2b42d5f3e97ed5dd47dc10f211cdc2322c1f6"
        public static let studentSchedule = "/_serverFn/85d2195b8f64b023a2c16160b65ef47139dea3a839096c4b75b3888cda49f16c"
        public static let teacherSchedule = "/_serverFn/9fd2616a2ecddd56f79974f2111a13f2c9d89265cb6832c8c9e7ae2939e56f4a"
        public static let groupSchedule = "/_serverFn/d418f54f8d5ba132bd168b1792cc8f0efbff634c7861f6aa66890cb9f7103c05"
        public static let logout = "/_serverFn/2e1ca1208f926608597adee62b6f7a786ebfd7e01b208963ecb9bee6e800f9f5"
        public static let studentHomework = "/_serverFn/6856a131ea327da0ae2769d0e8b9950bce030194dda15acd331dd5ad2c273f38"
        public static let studentWebinar = "/_serverFn/b218948fba15961755e1cf6c0742e352d8709719e99ac7bd3e06315787e13650"
        public static let groupHomework = "/_serverFn/c45239ec7e4dc5b1d502259920ddafa06eec8ce3391ba127bd60b4e86e07c60b"
        public static let groupWebinar = "/_serverFn/b45e772e2c78dafc8e71009e176b018dc30498e626381ce78c54098424cb9335"
    }

    /// Device identifier for fingerprint generation
    public static let deviceIdentifier = "ktk-ios-app"

    /// Keychain service identifier
    public static let keychainService = "ru.ktk.education-system.app"

    /// UserDefaults keys
    public struct UserDefaultsKeys {
        public static let isLoggedIn = "ktk.isLoggedIn"
        public static let lastLogin = "ktk.lastLogin"
        public static let savedCollegeId = "ktk.savedCollegeId"
        public static let sessionId = "ktk.sessionId"
        public static let userGroup = "ktk.userGroup"
        public static let userSubgroup = "ktk.userSubgroup"
        public static let userBranch = "ktk.userBranch"
        public static let isTeacher = "ktk.isTeacher"
        public static let teacherHash = "ktk.teacherHash"
        public static let personalEndpoint = "ktk.personalEndpoint"
        public static let groupEndpoint = "ktk.groupEndpoint"
        public static let branch = "ktk.branch"
        public static let callsEndpoint = "ktk.callsEndpoint"
        public static let typesEndpoint = "ktk.typesEndpoint"
        public static let absenceEndpoint = "ktk.absenceEndpoint"
        public static let fileHashEndpoint = "ktk.fileHashEndpoint"
        public static let homeworkHashEndpoint = "ktk.homeworkHashEndpoint"
    }
}