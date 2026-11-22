import Foundation
import Combine

/// ViewModel for authentication flow
@MainActor
public final class AuthViewModel: ObservableObject {
    public static let shared = AuthViewModel()

    // MARK: - Published Properties

    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var currentUser: UserProfile?

    // Login form state
    @Published public var collegeId = ""
    @Published public var password = ""
    @Published public var rememberMe = true

    // MARK: - Private Properties

    private let apiClient = APIClient.shared
    private let keychain = KeychainManager.shared
    private let userDefaults = UserDefaultsManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        checkExistingSession()
    }

    // MARK: - Public Methods

    /// Check if there's a valid saved session
    public func checkExistingSession() {
        guard let collegeId = userDefaults.savedCollegeId,
              !collegeId.isEmpty else { return }

        // Try to load session from keychain
        do {
            if let sessionRecord = try keychain.loadSessionRecord(for: collegeId),
               sessionRecord.isValid {
                // Restore session state
                restoreSession(from: sessionRecord, collegeId: collegeId)
                // Validate session by making a test request
                Task {
                    await validateSession()
                }
            } else if rememberMe {
                // Try to load credentials and auto-login
                if let credentials = try keychain.loadCredentials(collegeId: collegeId) {
                    self.collegeId = credentials.collegeId
                    self.password = credentials.password
                    Task {
                        await login()
                    }
                }
            }
        } catch {
            print("Failed to restore session: \(error)")
        }
    }

    /// Perform login
    public func login() async {
        guard !collegeId.isEmpty, !password.isEmpty else {
            errorMessage = "Введите логин и пароль"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.login(collegeId: collegeId, password: password)

            if response.isSuccess {
                let user = response.user
                let profile = UserProfile(
                    collegeId: user.collegeId,
                    isStudent: user.isStudent,
                    group: user.group?.id ?? 0,
                    subgroup: user.subgroup ?? "",
                    branch: user.branch ?? "",
                    teacherHash: user.hash ?? "",
                    sessionId: response.session?.id ?? user.session?.id ?? ""
                )

                currentUser = profile
                isAuthenticated = true

                // Save session state
                saveSessionState(profile: profile)

                // Save credentials if remember me
                if rememberMe {
                    try? keychain.saveCredentials(collegeId: collegeId, password: password)
                    userDefaults.savedCollegeId = collegeId
                }

                userDefaults.lastLogin = Date()
                userDefaults.isLoggedIn = true

                // Load initial schedule
                await loadInitialSchedule()
            } else {
                let errorMsg = response.error?.appError?.message ?? response.error?.message ?? "Неверный логин или пароль"
                errorMessage = errorMsg
                isAuthenticated = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }

        isLoading = false
    }

    /// Perform logout
    public func logout() async {
        isLoading = true

        do {
            try await apiClient.logout()
        } catch {
            print("Logout error: \(error)")
        }

        clearSession()
        isLoading = false
    }

    /// Validate current session
    public func validateSession() async {
        // Try to fetch schedule for current week as validation
        do {
            let week = Week.current()
            if currentUser?.isStudent == true {
                _ = try await apiClient.getStudentSchedule(weekStart: week.start)
            } else {
                _ = try await apiClient.getTeacherSchedule(weekStart: week.start)
            }
        } catch {
            // Session invalid, clear and require re-login
            await MainActor.run {
                clearSession()
                errorMessage = "Сессия истекла. Войдите в систему снова."
            }
        }
    }

    /// Load initial schedule after login
    private func loadInitialSchedule() async {
        let week = Week.current()
        do {
            if currentUser?.isStudent == true {
                _ = try await apiClient.getStudentSchedule(weekStart: week.start)
            } else {
                _ = try await apiClient.getTeacherSchedule(weekStart: week.start)
            }
        } catch {
            print("Failed to load initial schedule: \(error)")
        }
    }

    // MARK: - Private Methods

    private func restoreSession(from record: SessionRecord, collegeId: String) {
        userDefaults.sessionId = record.sessionId
        userDefaults.userGroup = record.group
        userDefaults.userSubgroup = record.subgroup
        userDefaults.userBranch = record.branch
        userDefaults.isTeacher = !record.teacher.isEmpty
        userDefaults.teacherHash = record.teacher
        userDefaults.personalEndpoint = record.personalEndpoint
        userDefaults.groupEndpoint = record.groupEndpoint
        userDefaults.branch = record.branch

        currentUser = UserProfile(
            collegeId: collegeId,
            isStudent: record.teacher.isEmpty,
            group: record.group,
            subgroup: record.subgroup,
            branch: record.branch,
            teacherHash: record.teacher,
            sessionId: record.sessionId
        )

        isAuthenticated = true
        userDefaults.isLoggedIn = true
        self.collegeId = collegeId
    }

    private func saveSessionState(profile: UserProfile) {
        userDefaults.sessionId = profile.sessionId
        userDefaults.userGroup = profile.group
        userDefaults.userSubgroup = profile.subgroup
        userDefaults.userBranch = profile.branch
        userDefaults.isTeacher = !profile.isStudent
        userDefaults.teacherHash = profile.teacherHash

        // Create and save session record
        let record = SessionRecord(
            cookie: apiClient.getCookieHeader(),
            sessionId: profile.sessionId,
            group: profile.group,
            subgroup: profile.subgroup,
            teacher: profile.teacherHash,
            branch: profile.branch,
            personalEndpoint: userDefaults.personalEndpoint,
            groupEndpoint: userDefaults.groupEndpoint
        )

        try? keychain.saveSessionRecord(record, for: profile.collegeId)
    }

    private func clearSession() {
        currentUser = nil
        isAuthenticated = false
        collegeId = ""
        password = ""
        errorMessage = nil

        userDefaults.clearLoginState()
        apiClient.clearSession()

        // Note: We don't clear keychain credentials unless user explicitly requests it
    }

    /// Clear saved credentials (for "forget me" functionality)
    public func clearSavedCredentials() throws {
        if let collegeId = userDefaults.savedCollegeId {
            try keychain.deleteCredentials(collegeId: collegeId)
            try keychain.deleteSessionRecord(for: collegeId)
        }
        userDefaults.savedCollegeId = nil
    }
}