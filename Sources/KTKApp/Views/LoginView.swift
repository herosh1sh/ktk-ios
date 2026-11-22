import SwiftUI

/// Login screen
struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case collegeId, password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top spacing
                    Spacer(minLength: 60)

                    // Logo and title
                    VStack(spacing: 16) {
                        // App logo/icon
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 80, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolRenderingMode(.hierarchical)

                        VStack(spacing: 4) {
                            Text("КТК Расписание")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("Курганский Технологический Колледж")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 48)

                    // Login form
                    VStack(spacing: 20) {
                        // College ID field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Номер студенческого/преподавателя")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("18902", text: $authViewModel.collegeId)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .collegeId)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Пароль")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SecureField("Пароль", text: $authViewModel.password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { Task { await authViewModel.login() } }
                        }

                        // Remember me toggle
                        Toggle(isOn: $authViewModel.rememberMe) {
                            Label("Запомнить меня", systemImage: "checkmark.circle")
                                .font(.subheadline)
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = authViewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Login button
                    Button(action: { Task { await authViewModel.login() } }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Text("Войти")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(authViewModel.isLoading || authViewModel.collegeId.isEmpty || authViewModel.password.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Info text
                    VStack(spacing: 4) {
                        Text("Данные для входа выдаются в колледже")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)

                        Text("Версия 1.0.0")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                focusedField = .collegeId
            }
        }
    }
}

/// Preview for LoginView
#Preview {
    LoginView()
        .environmentObject(AuthViewModel.shared)
}