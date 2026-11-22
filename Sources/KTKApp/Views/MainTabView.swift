import SwiftUI

/// Main tab view after login
struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Schedule tab
            NavigationStack {
                ScheduleView()
            }
            .tabItem {
                Label("Расписание", systemImage: "calendar")
            }
            .tag(0)

            // Homework tab
            NavigationStack {
                HomeworkView()
            }
            .tabItem {
                Label("Домашние задания", systemImage: "doc.text")
            }
            .tag(1)

            // Settings tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Настройки", systemImage: "gear")
            }
            .tag(2)
        }
        .tint(.blue)
    }
}

/// Schedule view
struct ScheduleView: View {
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingWeekPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Week selector header
            weekSelectorHeader

            // Scope picker (personal/group)
            scopePicker

            // Schedule list
            if scheduleViewModel.isLoading && scheduleViewModel.schedule.isEmpty {
                loadingView
            } else if scheduleViewModel.schedule.isEmpty {
                emptyStateView
            } else {
                scheduleList
            }
        }
        .navigationTitle("Расписание")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { Task { await scheduleViewModel.refresh() } }) {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                    Button(action: { scheduleViewModel.goToCurrentWeek() }) {
                        Label("Текущая неделя", systemImage: "calendar.badge.clock")
                    }
                    Divider()
                    Button(role: .destructive, action: { Task { await authViewModel.logout() } }) {
                        Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await scheduleViewModel.refresh()
        }
        .task {
            if scheduleViewModel.schedule.isEmpty {
                await scheduleViewModel.loadSchedule()
            }
        }
    }

    // MARK: - Subviews

    private var weekSelectorHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { scheduleViewModel.previousWeek() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.blue)
                }

                Spacer()

                Button(action: { showingWeekPicker = true }) {
                    VStack(spacing: 2) {
                        Text(scheduleViewModel.selectedWeek.formattedRange)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Неделя \(scheduleViewModel.selectedWeek.number), \(scheduleViewModel.selectedWeek.academicYear) уч. год")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: { scheduleViewModel.nextWeek() }) {
                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingWeekPicker) {
            WeekPickerView(selectedWeek: $scheduleViewModel.selectedWeek)
        }
    }

    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ScopeButton(
                    title: "Личное",
                    isSelected: scheduleViewModel.selectedScope == .personal
                ) {
                    scheduleViewModel.setScope(.personal)
                }

                if let user = authViewModel.currentUser, user.isStudent, user.group > 0 {
                    ScopeButton(
                        title: "Группа \(user.group)",
                        isSelected: scheduleViewModel.selectedScope == .group(groupId: user.group)
                    ) {
                        scheduleViewModel.setScope(.group(groupId: user.group))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var scheduleList: some View {
        List {
            ForEach(scheduleViewModel.schedule) { day in
                Section(header: dayHeader(day)) {
                    let subjects = scheduleViewModel.subjectsForDay(day)
                    if subjects.isEmpty {
                        Text("Занятий нет")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(subjects) { subject in
                            SubjectRow(subject: subject, day: day)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private func dayHeader(_ day: ScheduleDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.dayOfWeek)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(day.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if day.today {
                Label("Сегодня", systemImage: "circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .labelStyle(.titleAndIcon)
            }
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Загрузка расписания...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Расписание не найдено")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Попробуйте обновить или выбрать другую неделю")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Subject row in schedule
struct SubjectRow: View {
    let subject: Subject
    let day: ScheduleDay
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @State private var showingHomework = false
    @State private var homeworkData: HomeworkData?
    @State private var webinarLink: WebinarLink?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Time and pair number
            HStack {
                Text("Пара \(subject.pair)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Text(scheduleViewModel.timeRange(for: subject.pair, callPresetId: day.callPreset))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Subject info
            VStack(alignment: .leading, spacing: 6) {
                Text(subject.discipline)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    if !subject.teacher.isEmpty {
                        Label(subject.teacher, systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label(subject.location, systemImage: "door.left.hand.open")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !subject.subgroup.isEmpty {
                    Text("Подгруппа: \(subject.subgroup)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Homework indicator
            if subject.extendedData.hasHomework {
                Button(action: { loadHomework() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                        Text("Домашнее задание")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Webinar indicator
            if subject.extendedData.webinar || subject.extendedData.remote {
                Button(action: { loadWebinar() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                        Text("Вебинар")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingHomework) {
            if let homework = homeworkData {
                HomeworkDetailView(homework: homework, subject: subject)
            }
        }
        .sheet(item: $webinarLink) { link in
            WebinarDetailView(link: link, subject: subject)
        }
    }

    private func loadHomework() {
        guard let journalId = subject.extraData?.sheet, journalId > 0 else { return }
        Task {
            if let hw = await scheduleViewModel.loadHomework(for: subject, journalId: journalId) {
                await MainActor.run {
                    homeworkData = hw
                    showingHomework = true
                }
            }
        }
    }

    private func loadWebinar() {
        guard let journalId = subject.extraData?.sheet, journalId > 0 else { return }
        Task {
            if let link = await scheduleViewModel.loadWebinar(for: subject, journalId: journalId) {
                await MainActor.run {
                    webinarLink = link
                }
            }
        }
    }
}

/// Scope button for schedule scope picker
struct ScopeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemBackground))
                )
                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Week picker sheet
struct WeekPickerView: View {
    @Binding var selectedWeek: Week
    @Environment(\.dismiss) private var dismiss
    @State private var tempWeek: Week

    init(selectedWeek: Binding<Week>) {
        self._selectedWeek = selectedWeek
        self._tempWeek = State(initialValue: selectedWeek.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(-4...4, id: \.self) { offset in
                    let week = Week.current().offset(by: offset)
                    Button(action: {
                        tempWeek = week
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(week.formattedRange)
                                    .font(.headline)
                                Text("Неделя \(week.number), \(week.academicYear) уч. год")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if tempWeek.millis == week.millis {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Выбрать неделю")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        selectedWeek = tempWeek
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension Week {
    func offset(by weeks: Int) -> Week {
        let calendar = Calendar.current
        let newStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: start) ?? start
        return Week.week(for: newStart)
    }
}

/// Preview
#Preview {
    MainTabView()
        .environmentObject(AuthViewModel.shared)
        .environmentObject(ScheduleViewModel.shared)
}