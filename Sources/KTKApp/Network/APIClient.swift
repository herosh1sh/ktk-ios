import Foundation
import Alamofire
import CryptoSwift

/// Main API client for communicating with KTK Education System
public final class APIClient {
    public static let shared = APIClient()

    private let session: Session
    private let baseURL: String
    private var currentCookies: [HTTPCookie] = []
    private let cookieStorage = HTTPCookieStorage.shared
    private let endpointLock = NSLock()
    private var discoveredEndpoints: [String: String] = [:]

    private init() {
        self.baseURL = AppConfiguration.baseURL

        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpCookieStorage = cookieStorage
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Set default headers
        configuration.httpAdditionalHeaders = AppConfiguration.defaultHeaders

        self.session = Session(configuration: configuration)
    }

    // MARK: - Authentication

    /// Login with college ID and password
    /// - Parameters:
    ///   - collegeId: Student/teacher ID
    ///   - password: Password
    /// - Returns: LoginResponse with user info
    public func login(collegeId: String, password: String) async throws -> LoginResponse {
        let fingerprint = generateFingerprint(login: collegeId, device: AppConfiguration.deviceIdentifier)

        let request = LoginRequest(
            collegeId: collegeId,
            password: password,
            fingerprint: fingerprint
        )

        let url = baseURL + AppConfiguration.ServerFunctions.signIn
        let referer = baseURL + "/welcome?redirect=%2F"

        var headers = AppConfiguration.defaultHeaders
        headers["Referer"] = referer
        headers["Origin"] = baseURL

        let response: LoginResponse = try await performRequest(
            url: url,
            method: .post,
            parameters: request,
            headers: HTTPHeaders(headers),
            encoding: JSONEncoding.default
        )

        // Store cookies after successful login
        if response.isSuccess {
            storeCookies()
            if let sessionId = response.session?.id ?? response.user.session?.id {
                saveSessionId(sessionId)
            }
        }

        return response
    }

    /// Logout from the system
    public func logout() async throws {
        guard let sessionId = getSessionId(), !sessionId.isEmpty else { return }

        let url = baseURL + AppConfiguration.ServerFunctions.logout
        let parameters = ["id": sessionId]

        let _: LoginResponse = try await performRequest(
            url: url,
            method: .post,
            parameters: parameters,
            headers: HTTPHeaders(defaultHeadersWithReferer()),
            encoding: JSONEncoding.default
        )

        clearSession()
    }

    // MARK: - Schedule

    /// Get student's personal schedule for a week
    public func getStudentSchedule(weekStart: Date) async throws -> [ScheduleDay] {
        let weekStartString = formatWeekStart(weekStart)
        let url = baseURL + (discoveredEndpoints["student"] ?? AppConfiguration.ServerFunctions.studentSchedule)

        let parameters = ["weekStart": weekStartString]
        let headers = defaultHeadersWithReferer()

        return try await performRequestWithRetry(
            url: url,
            method: .get,
            parameters: parameters,
            headers: HTTPHeaders(headers),
            endpointKey: "student",
            defaultEndpoint: AppConfiguration.ServerFunctions.studentSchedule
        )
    }

    /// Get teacher's schedule for a week
    public func getTeacherSchedule(weekStart: Date) async throws -> [ScheduleDay] {
        let weekStartString = formatWeekStart(weekStart)
        let url = baseURL + (discoveredEndpoints["teacher"] ?? AppConfiguration.ServerFunctions.teacherSchedule)

        let parameters = ["weekStart": weekStartString]
        let headers = defaultHeadersWithReferer()

        return try await performRequestWithRetry(
            url: url,
            method: .get,
            parameters: parameters,
            headers: HTTPHeaders(headers),
            endpointKey: "teacher",
            defaultEndpoint: AppConfiguration.ServerFunctions.teacherSchedule
        )
    }

    /// Get group schedule for a week
    public func getGroupSchedule(groupId: Int, weekStart: Date) async throws -> [ScheduleDay] {
        let weekStartString = formatWeekStart(weekStart)
        let url = baseURL + (discoveredEndpoints["group"] ?? AppConfiguration.ServerFunctions.groupSchedule)

        let parameters = [
            "groupId": String(groupId),
            "weekStart": weekStartString
        ]
        let headers = defaultHeadersWithReferer()

        return try await performRequestWithRetry(
            url: url,
            method: .get,
            parameters: parameters,
            headers: HTTPHeaders(headers),
            endpointKey: "group",
            defaultEndpoint: AppConfiguration.ServerFunctions.groupSchedule
        )
    }

    // MARK: - Homework & Webinars

    /// Get homework for a specific lesson
    public func getLessonHomework(journalId: Int, groupId: String?, weekStart: Date) async throws -> HomeworkData? {
        let weekStartString = formatWeekStart(weekStart)
        let url = baseURL + (discoveredEndpoints["studentHomework"] ?? AppConfiguration.ServerFunctions.studentHomework)

        var parameters: [String: String] = [
            "journalId": String(journalId),
            "weekStart": weekStartString
        ]
        if let groupId = groupId, !groupId.isEmpty {
            parameters["groupId"] = groupId
        }

        let headers = defaultHeadersWithReferer()

        // The response structure may vary, try to decode as HomeworkData
        let response: HomeworkResponse = try await performRequest(
            url: url,
            method: .get,
            parameters: parameters,
            headers: HTTPHeaders(headers)
        )
        return response.data
    }

    /// Get webinar link for a specific lesson
    public func getLessonWebinar(journalId: Int, groupId: String?, weekStart: Date) async throws -> WebinarLink? {
        let weekStartString = formatWeekStart(weekStart)
        let url = baseURL + (discoveredEndpoints["studentWebinar"] ?? AppConfiguration.ServerFunctions.studentWebinar)

        var parameters: [String: String] = [
            "journalId": String(journalId),
            "weekStart": weekStartString
        ]
        if let groupId = groupId, !groupId.isEmpty {
            parameters["groupId"] = groupId
        }

        let headers = defaultHeadersWithReferer()

        let response: WebinarResponse = try await performRequest(
            url: url,
            method: .get,
            parameters: parameters,
            headers: HTTPHeaders(headers)
        )
        return response.data
    }

    // MARK: - Reference Data

    /// Get call presets (time schedule)
    public func getCallPresets() async throws -> [CallPreset] {
        // This would typically come from a discovered endpoint
        // For now, return empty array - implement discovery when needed
        return []
    }

    /// Get pair types
    public func getPairTypes() async throws -> [PairType] {
        return []
    }

    /// Get lecture halls
    public func getLectureHalls(branch: String) async throws -> [LectureHall] {
        return []
    }

    // MARK: - Discovery

    /// Discover API endpoints by crawling the site
    public func discoverEndpoints() async throws {
        // Fetch main page and scripts to find server function IDs
        // This mirrors the Rust implementation's crawl() function
        let mainPageUrl = baseURL + "/"
        let html = try await fetchText(url: mainPageUrl)

        // Extract server function IDs from HTML
        let serverFnPattern = #"/_serverFn/([a-fA-F0-9]{32,64})"#
        let regex = try NSRegularExpression(pattern: serverFnPattern)
        let range = NSRange(location: 0, length: html.utf16.count)

        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let range = Range(match.range(at: 0), in: html) else { return }
            let path = String(html[range])
            // Categorize based on context (simplified)
            self.categorizeEndpoint(path, context: html)
        }

        // Also fetch and parse JS files
        let scriptUrls = extractScriptUrls(from: html, base: baseURL)
        for scriptUrl in scriptUrls.prefix(10) {
            if let scriptContent = try? await fetchText(url: scriptUrl) {
                regex.enumerateMatches(in: scriptContent, options: [], range: NSRange(location: 0, length: scriptContent.utf16.count)) { match, _, _ in
                    guard let match = match,
                          let range = Range(match.range(at: 0), in: scriptContent) else { return }
                    let path = String(scriptContent[range])
                    self.categorizeEndpoint(path, context: scriptContent)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func generateFingerprint(login: String, device: String) -> String {
        let input = login + device
        let hash = input.sha256()
        return String(hash.prefix(32)) // First 16 bytes = 32 hex chars
    }

    private func defaultHeadersWithReferer() -> [String: String] {
        var headers = AppConfiguration.defaultHeaders
        headers["Referer"] = baseURL
        headers["Origin"] = baseURL
        return headers
    }

    private func performRequest<T: Decodable>(
        url: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders,
        encoding: ParameterEncoding = URLEncoding.default
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: headers
            )
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let value):
                    self.storeCookies()
                    continuation.resume(returning: value)
                case .failure(let error):
                    // Try to parse error response
                    if let data = response.data,
                       let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                        continuation.resume(throwing: APIError.networkError(apiError.message ?? error.localizedDescription))
                    } else {
                        continuation.resume(throwing: APIError.networkError(error.localizedDescription))
                    }
                }
            }
        }
    }

    private func performRequestWithRetry(
        url: String,
        method: HTTPMethod,
        parameters: Parameters?,
        headers: HTTPHeaders,
        endpointKey: String,
        defaultEndpoint: String
    ) async throws -> [ScheduleDay] {
        do {
            let response: [ScheduleDay] = try await performRequest(
                url: url,
                method: method,
                parameters: parameters,
                headers: headers
            )
            return response
        } catch {
            // If endpoint not found (404) or gone, try rediscovery
            if case APIError.endpointNotFound = error {
                try await discoverEndpoints()
                let newUrl = baseURL + (discoveredEndpoints[endpointKey] ?? defaultEndpoint)
                let response: [ScheduleDay] = try await performRequest(
                    url: newUrl,
                    method: method,
                    parameters: parameters,
                    headers: headers
                )
                return response
            }
            throw error
        }
    }

    private func fetchText(url: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(url, headers: HTTPHeaders(defaultHeadersWithReferer()))
                .validate()
                .responseString { response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    private func extractScriptUrls(from html: String, base: String) -> [String] {
        let scriptPattern = #"<script[^>]+src=["']([^"']+\.js(?:\?[^"']*)?)["']"#
        let regex = try? NSRegularExpression(pattern: scriptPattern)
        let range = NSRange(location: 0, length: html.utf16.count)
        var urls: [String] = []

        regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let range = Range(match.range(at: 1), in: html) else { return }
            let src = String(html[range])
            if let url = URL(string: src, relativeTo: URL(string: base)) {
                urls.append(url.absoluteString)
            }
        }

        return urls
    }

    private func categorizeEndpoint(_ path: String, context: String) {
        endpointLock.lock()
        defer { endpointLock.unlock() }

        // Find context around the endpoint to categorize it
        let idx = context.range(of: path)?.lowerBound ?? context.startIndex
        let start = context.index(idx, offsetBy: -min(200, context.distance(from: context.startIndex, to: idx)), limitedBy: context.startIndex) ?? context.startIndex
        let end = context.index(idx, offsetBy: min(200, context.distance(from: idx, to: context.endIndex)), limitedBy: context.endIndex) ?? context.endIndex
        let snippet = String(context[start..<end])

        if snippet.contains("collegeId") || snippet.contains("fingerprint") {
            discoveredEndpoints["signIn"] = path
        } else if snippet.contains("groupId") && snippet.contains("weekStart") {
            discoveredEndpoints["group"] = path
        } else if snippet.contains("weekStart") {
            if snippet.contains("teacher") || snippet.contains("Teacher") {
                discoveredEndpoints["teacher"] = path
            } else {
                discoveredEndpoints["student"] = path
            }
        } else if snippet.contains("revoke") || snippet.contains("logout") || snippet.contains("signOut") {
            discoveredEndpoints["logout"] = path
        } else if snippet.contains("homework") && snippet.contains("journalId") {
            discoveredEndpoints["studentHomework"] = path
        } else if snippet.contains("webinar") && snippet.contains("journalId") {
            discoveredEndpoints["studentWebinar"] = path
        }
    }

    private func formatWeekStart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    // MARK: - Cookie Management

    private func storeCookies() {
        if let cookies = cookieStorage.cookies(for: URL(string: baseURL)!) {
            currentCookies = cookies
            // Persist cookie header for session restoration
            let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            UserDefaults.standard.set(cookieHeader, forKey: AppConfiguration.UserDefaultsKeys.savedCollegeId + "_cookies")
        }
    }

    private func restoreCookies() {
        if let cookieHeader = UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKeys.savedCollegeId + "_cookies"),
           let url = URL(string: baseURL) {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": cookieHeader], for: url)
            cookies.forEach { cookieStorage.setCookie($0) }
            currentCookies = cookies
        }
    }

    public func getCookieHeader() -> String {
        return currentCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    // MARK: - Session Persistence

    private func saveSessionId(_ sessionId: String) {
        UserDefaults.standard.set(sessionId, forKey: AppConfiguration.UserDefaultsKeys.sessionId)
    }

    public func getSessionId() -> String? {
        return UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKeys.sessionId)
    }

    public func clearSession() {
        let keys = [
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
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        currentCookies.removeAll()
        if let cookies = cookieStorage.cookies(for: URL(string: baseURL)!) {
            cookies.forEach { cookieStorage.deleteCookie($0) }
        }
    }
}

// MARK: - API Error

public enum APIError: LocalizedError {
    case networkError(String)
    case authenticationFailed(String)
    case endpointNotFound
    case sessionExpired
    case invalidResponse
    case decodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .authenticationFailed(let message):
            return "Ошибка авторизации: \(message)"
        case .endpointNotFound:
            return "Эндпоинт не найден. Попробуйте обновить расписание."
        case .sessionExpired:
            return "Сессия истекла. Войдите в систему снова."
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .decodingError(let error):
            return "Ошибка обработки данных: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Wrappers for Homework/Webinar

private struct HomeworkResponse: Decodable {
    let data: HomeworkData?
    let error: APIError?
}

private struct WebinarResponse: Decodable {
    let data: WebinarLink?
    let error: APIError?
}