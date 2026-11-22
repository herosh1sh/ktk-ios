import SwiftUI

/// Homework view - shows all homework for the selected week
struct HomeworkView: View {
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @State private var homeworkItems: [HomeworkItem] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && homeworkItems.isEmpty {
                    loadingView
                } else if homeworkItems.isEmpty {
                    emptyStateView
                } else {
                    homeworkList
                }
            }
            .navigationTitle("Домашние задания")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await loadHomework() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await loadHomework()
            }
            .task {
                if homeworkItems.isEmpty {
                    await loadHomework()
                }
            }
        }
    }

    private var homeworkList: some View {
        List {
            ForEach(homeworkItems) { item in
                NavigationLink(destination: HomeworkDetailView(homework: item.homework, subject: item.subject)) {
                    HomeworkRow(item: item)
                }
            }
        }
        .listStyle(.plain)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Загрузка заданий...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Заданий нет")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("На этой неделе домашних заданий не найдено")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadHomework() async {
        isLoading = true
        var items: [HomeworkItem] = []

        // Collect all subjects with homework from current schedule
        for day in scheduleViewModel.schedule {
            let subjects = scheduleViewModel.subjectsForDay(day)
            for subject in subjects where subject.extendedData.hasHomework {
                guard let journalId = subject.extraData?.sheet, journalId > 0 else { continue }
                if let hw = await scheduleViewModel.loadHomework(for: subject, journalId: journalId) {
                    items.append(HomeworkItem(
                        subject: subject,
                        day: day,
                        homework: hw
                    ))
                }
            }
        }

        await MainActor.run {
            homeworkItems = items.sorted { $0.day.date < $1.day.date }
            isLoading = false
        }
    }
}

/// Homework item for list display
struct HomeworkItem: Identifiable {
    let id = UUID()
    let subject: Subject
    let day: ScheduleDay
    let homework: HomeworkData
}

/// Homework row in list
struct HomeworkRow: View {
    let item: HomeworkItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.subject.discipline)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(item.day.dayOfWeek)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            if let text = item.homework.text, !text.isEmpty {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if let deadline = item.homework.deadline {
                    Label(deadline, systemImage: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let files = item.homework.files, !files.isEmpty {
                    Label("\(files.count) файлов", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Homework detail view
struct HomeworkDetailView: View {
    let homework: HomeworkData
    let subject: Subject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Subject header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subject.discipline)
                            .font(.title2.weight(.bold))
                        Text(subject.teacher)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Description
                    if let text = homework.text, !text.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Задание", systemImage: "doc.text")
                                .font(.headline)
                            Text(text)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Deadline
                    if let deadline = homework.deadline {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Срок сдачи", systemImage: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text(deadline)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Files
                    if let files = homework.files, !files.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Файлы (\(files.count))", systemImage: "paperclip")
                                .font(.headline)

                            ForEach(files) { file in
                                HomeworkFileRow(file: file)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Webinar
                    if let webinar = homework.webinar {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Вебинар", systemImage: "video.fill")
                                .font(.headline)
                                .foregroundStyle(.purple)
                            if let title = webinar.title {
                                Text(title)
                                    .font(.body)
                            }
                            Link(destination: URL(string: webinar.url) ?? URL(string: "https://")!) {
                                Label("Открыть вебинар", systemImage: "arrow.up.right.square")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding()
            }
            .navigationTitle("Задание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

/// File row in homework detail
struct HomeworkFileRow: View {
    let file: HomeworkFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon(for: file.fileExtension))
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.caption)
                    .font(.subheadline.weight(.medium))
                Text(".\(file.fileExtension) • Неделя \(file.weekStart)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fileIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "rectangle.on.rectangle.fill"
        case "zip", "rar", "7z": return "archivebox.fill"
        case "jpg", "jpeg", "png", "gif": return "photo.fill"
        case "mp4", "mov", "avi": return "film.fill"
        default: return "doc.fill"
        }
    }
}

/// Webinar detail view
struct WebinarDetailView: View {
    let link: WebinarLink
    let subject: Subject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "video.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.purple)

                Text(subject.discipline)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                if let title = link.title {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Label("Ссылка на вебинар", systemImage: "link")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(link.url)
                        .font(.body.monospaced())
                        .foregroundStyle(.blue)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Link(destination: URL(string: link.url) ?? URL(string: "https://")!) {
                    Label("Открыть в браузере", systemImage: "safari")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("Вебинар")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

/// Preview
#Preview {
    HomeworkView()
        .environmentObject(ScheduleViewModel.shared)
        .environmentObject(AuthViewModel.shared)
}