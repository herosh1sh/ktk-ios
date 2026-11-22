import Foundation
import Combine

/// ViewModel for schedule management
@MainActor
public final class ScheduleViewModel: ObservableObject {
    public static let shared = ScheduleViewModel()

    // MARK: - Published Properties

    @Published public private(set) var schedule: [ScheduleDay] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public var selectedWeek = Week.current()
    @Published public var selectedScope: ScheduleScope = .personal
    @Published public var showSubgroupOnly = true
    @Published public var referenceData: ReferenceData?

    // MARK: - Private Properties

    private let apiClient = APIClient.shared
    private let authViewModel = AuthViewModel.shared
    private let userDefaults = UserDefaultsManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCachedData()
        setupBindings()
    }

    // MARK: - Public Methods

    /// Load schedule for current selection
    public func loadSchedule() async {
        guard authViewModel.isAuthenticated else { return }

        isLoading = true
        errorMessage = nil

        // Check cache first
        if let cached = userDefaults.loadScheduleCache(forWeek: selectedWeek, scope: selectedScope.rawValue) {
            self.schedule = cached
            self.isLoading = false
            return
        }

        do {
            let newSchedule: [ScheduleDay]
            let user = authViewModel.currentUser

            switch selectedScope {
            case .personal:
                if user?.isStudent == true {
                    newSchedule = try await apiClient.getStudentSchedule(weekStart: selectedWeek.start)
                } else {
                    newSchedule = try await apiClient.getTeacherSchedule(weekStart: selectedWeek.start)
                }
            case .group(let groupId):
                newSchedule = try await apiClient.getGroupSchedule(groupId: groupId, weekStart: selectedWeek.start)
            }

            self.schedule = newSchedule
            userDefaults.saveScheduleCache(newSchedule, forWeek: selectedWeek, scope: selectedScope.rawValue)

            // Enrich with reference data (times, etc.)
            await enrichScheduleWithReferenceData()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Load homework for a specific lesson
    public func loadHomework(for subject: Subject, journalId: Int) async -> HomeworkData? {
        guard authViewModel.isAuthenticated else { return nil }

        let groupId = selectedScope == .group ? String(selectedWeek.number) : nil

        do {
            return try await apiClient.getLessonHomework(
                journalId: journalId,
                groupId: groupId,
                weekStart: selectedWeek.start
            )
        } catch {
            print("Failed to load homework: \(error)")
            return nil
        }
    }

    /// Load webinar for a specific lesson
    public func loadWebinar(for subject: Subject, journalId: Int) async -> WebinarLink? {
        guard authViewModel.isAuthenticated else { return nil }

        let groupId = selectedScope == .group ? String(selectedWeek.number) : nil

        do {
            return try await apiClient.getLessonWebinar(
                journalId: journalId,
                groupId: groupId,
                weekStart: selectedWeek.start
            )
        } catch {
            print("Failed to load webinar: \(error)")
            return nil
        }
    }

    /// Navigate to next week
    public func nextWeek() {
        selectedWeek = selectedWeek.nextWeek()
        Task { await loadSchedule() }
    }

    /// Navigate to previous week
    public func previousWeek() {
        selectedWeek = selectedWeek.previousWeek()
        Task { await loadSchedule() }
    }

    /// Go to current week
    public func goToCurrentWeek() {
        selectedWeek = Week.current()
        Task { await loadSchedule() }
    }

    /// Change scope (personal/group)
    public func setScope(_ scope: ScheduleScope) {
        selectedScope = scope
        Task { await loadSchedule() }
    }

    /// Refresh current schedule (force reload)
    public func refresh() async {
        userDefaults.clearScheduleCache()
        await loadSchedule()
    }

    /// Discover API endpoints
    public func discoverEndpoints() async {
        do {
            try await apiClient.discoverEndpoints()
        } catch {
            print("Endpoint discovery failed: \(error)")
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Observe auth state changes
        authViewModel.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                if isAuth {
                    Task { await self?.loadSchedule() }
                } else {
                    self?.schedule = []
                }
            }
            .store(in: &cancellables)

        // Observe week changes
        $selectedWeek
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadSchedule() }
            }
            .store(in: &cancellables)

        // Load reference data
        Task { await loadReferenceData() }
    }

    private func loadCachedData() {
        // Load cached schedule for current week
        if let cached = userDefaults.loadScheduleCache(forWeek: selectedWeek, scope: selectedScope.rawValue) {
            schedule = cached
        }

        // Load reference data
        if let refData = userDefaults.loadReferenceData() {
            referenceData = refData
        }

        // Load settings
        showSubgroupOnly = userDefaults.showSubgroupOnly
    }

    private func loadReferenceData() async {
        // Try to load from cache first
        if let cached = userDefaults.loadReferenceData() {
            referenceData = cached
            return
        }

        // TODO: Implement fetching reference data from API
        // For now, create empty reference data
        referenceData = ReferenceData(calls: [], types: [], halls: [])
    }

    private func enrichScheduleWithReferenceData() async {
        guard let refData = referenceData else { return }

        // Enrich schedule with call preset times
        for (dayIndex, day) in schedule.enumerated() {
            if let preset = refData.calls.first(where: { $0.id == day.callPreset }) {
                var updatedDay = day
                // We can't modify directly, but we can update the view model's copy
                // The view will use referenceData to display times
            }
        }
    }

    // MARK: - Filtering

    /// Get subjects for a specific day, filtered by subgroup
    public func subjectsForDay(_ day: ScheduleDay) -> [Subject] {
        guard let user = authViewModel.currentUser else { return day.subjects }

        if showSubgroupOnly && user.isStudent && !user.subgroup.isEmpty {
            return day.subjects.filter { subject in
                subject.subgroup.isEmpty || subject.subgroup == user.subgroup
            }
        }
        return day.subjects
    }

    /// Get time range for a pair number
    public func timeRange(for pair: Int, callPresetId: Int) -> String {
        guard let preset = referenceData?.calls.first(where: { $0.id == callPresetId }),
              let callPair = preset.pairs.first(where: { $0.number == pair }) else {
            return "Пара \(pair)"
        }
        return "\(callPair.startTime) – \(callPair.endTime)"
    }

    /// Get pair type name
    public func pairTypeName(for subject: Subject) -> String {
        // The subject doesn't directly have pair type, but we could infer from discipline
        return subject.discipline
    }
}

// MARK: - Schedule Scope

public enum ScheduleScope: Equatable, Hashable {
    case personal
    case group(groupId: Int)

    public var rawValue: String {
        switch self {
        case .personal: return "personal"
        case .group(let id): return "group_\(id)"
        }
    }

    public var displayName: String {
        switch self {
        case .personal: return "Личное"
        case .group(let id): return "Группа \(id)"
        }
    }
}