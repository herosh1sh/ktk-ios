import SwiftUI

/// Settings view
struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @StateObject private var userDefaults = UserDefaultsManager.shared

    @State private var showingLogoutAlert = false
    @State private var showingClearCacheAlert = false
    @State private var showingForgetAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Account section
                if authViewModel.isAuthenticated, let user = authViewModel.currentUser {
                    Section {
                        ProfileRow(user: user)
                    } header: {
                        Text("Аккаунт")
                    }
                }

                // Appearance section
                Section {
                    Picker("Тема", selection: $userDefaults.themeMode) {
                        Text("Системная").tag("system")
                        Text("Светлая").tag("light")
                        Text("Тёмная").tag("dark")
                    }

                    Toggle("Показывать только свою подгруппу", isOn: $scheduleViewModel.showSubgroupOnly)
                        .onChange(of: scheduleViewModel.showSubgroupOnly) { _, newValue in
                            userDefaults.showSubgroupOnly = newValue
                        }
                } header: {
                    Text("Внешний вид")
                }

                // Schedule section
                Section {
                    Toggle("Автообновление расписания", isOn: $userDefaults.autoRefreshEnabled)

                    Toggle("Уведомления о заданиях", isOn: $userDefaults.notificationsEnabled)
                } header: {
                    Text("Расписание")
                }

                // Data section
                Section {
                    Button(action: { showingClearCacheAlert = true }) {
                        Label("Очистить кэш расписания", systemImage: "trash")
                            .foregroundStyle(.red)
                    }

                    Button(action: { Task { await scheduleViewModel.discoverEndpoints() } }) {
                        Label("Обновить адреса API", systemImage: "arrow.clockwise.icloud")
                    }
                } header: {
                    Text("Данные")
                } footer: {
                    Text("Очистка кэша может помочь, если расписание отображается некорректно")
                }

                // Account actions
                if authViewModel.isAuthenticated {
                    Section {
                        Button(action: { showingForgetAlert = true }) {
                            Label("Забыть аккаунт", systemImage: "person.badge.minus")
                                .foregroundStyle(.orange)
                        }

                        Button(action: { showingLogoutAlert = true }) {
                            Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Действия")
                    }
                }

                // About section
                Section {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/kurumihere/ktk-schedule")!) {
                        HStack {
                            Text("Исходный код")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.blue)
                        }
                    }

                    Link(destination: URL(string: "https://ktk.education-system.ru")!) {
                        HStack {
                            Text("Сайт колледжа")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("О приложении")
                } footer: {
                    Text("Неофициальное приложение для Курганского Технологического Колледжа. Данные предоставляются системой education-system.ru")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .alert("Выйти из аккаунта?", isPresented: $showingLogoutAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Выйти", role: .destructive) {
                    Task { await authViewModel.logout() }
                }
            } message: {
                Text("Вы будете выведены из системы. При включенной опции «Запомнить меня» вы сможете войти снова без ввода пароля.")
            }
            .alert("Очистить кэш?", isPresented: $showingClearCacheAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    userDefaults.clearScheduleCache()
                    scheduleViewModel.schedule = []
                    Task { await scheduleViewModel.loadSchedule() }
                }
            } message: {
                Text("Это удалит все сохраненные расписания. При следующем открытии они загрузятся заново.")
            }
            .alert("Забыть аккаунт?", isPresented: $showingForgetAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Забыть", role: .destructive) {
                    try? authViewModel.clearSavedCredentials()
                    await authViewModel.logout()
                }
            } message: {
                Text("Это удалит сохраненные учетные данные из ключевого цепочки. При следующем входе придется ввести логин и пароль заново.")
            }
        }
    }
}

/// Profile row in settings
struct ProfileRow: View {
    let user: UserProfile

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(user.isStudent ? Color.blue.gradient : Color.green.gradient)
                    .frame(width: 56, height: 56)

                Image(systemName: user.isStudent ? "person.fill" : "person.2.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                Text(user.groupDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

/// Preview
#Preview {
    SettingsView()
        .environmentObject(AuthViewModel.shared)
        .environmentObject(ScheduleViewModel.shared)
}