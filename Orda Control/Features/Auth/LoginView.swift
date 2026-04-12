import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    init(sessionStore: SessionStore) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        loginHeader

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            Picker("Режим входа", selection: $viewModel.mode) {
                                Text("По email").tag(LoginViewModel.Mode.email)
                                Text("По логину").tag(LoginViewModel.Mode.operatorLogin)
                            }
                            .pickerStyle(.segmented)
                            .colorMultiply(.white)

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text(viewModel.mode == .email ? "Email" : "Логин оператора")
                                    .font(AppTheme.Typography.micro)
                                    .textCase(.uppercase)
                                    .tracking(1.2)
                                    .foregroundStyle(AppTheme.Colors.textMuted)

                                TextField(
                                    viewModel.mode == .email ? "Введите email" : "Введите логин оператора",
                                    text: $viewModel.login
                                )
                                .textInputAutocapitalization(.never)
                                .keyboardType(viewModel.mode == .email ? .emailAddress : .default)
                                .autocorrectionDisabled()
                                .accessibilityLabel(viewModel.mode == .email ? "Введите email" : "Введите логин оператора")
                                .appInputStyle()

                                Text("Пароль")
                                    .font(AppTheme.Typography.micro)
                                    .textCase(.uppercase)
                                    .tracking(1.2)
                                    .foregroundStyle(AppTheme.Colors.textMuted)

                                SecureField("Введите пароль", text: $viewModel.password)
                                    .accessibilityLabel("Введите пароль")
                                    .appInputStyle()
                            }

                            if let errorMessage = viewModel.errorMessage {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                    Text(ServerJSONPlaintext.normalize(errorMessage))
                                        .foregroundStyle(AppTheme.Colors.error)
                                        .font(AppTheme.Typography.caption)
                                    if viewModel.canQuickResendReset {
                                        Button("Отправить письмо снова") {
                                            viewModel.isForgotPasswordSheetPresented = true
                                            Task { await viewModel.resendResetFromCurrentContext() }
                                        }
                                        .font(AppTheme.Typography.captionBold)
                                        .foregroundStyle(AppTheme.Colors.accentBlue)
                                    } else if viewModel.resetResendCooldown > 0 {
                                        Text("Повторно можно через \(viewModel.resetResendCooldown) сек")
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.textMuted)
                                    }
                                }
                                .padding(AppTheme.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.Colors.errorBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                        .stroke(AppTheme.Colors.errorBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            }

                            if viewModel.isRecoveringResetLink {
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    ProgressView().tint(AppTheme.Colors.accentBlue)
                                    Text("Проверяем ссылку восстановления…")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                                .padding(AppTheme.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.Colors.info.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                        .stroke(AppTheme.Colors.info.opacity(0.35), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            }

                            Button {
                                AppHaptics.selection()
                                Task { await viewModel.signIn() }
                            } label: {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Войти")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(viewModel.isLoading)
                            .accessibilityHint("Выполнить вход в приложение")

                            Button("Создать аккаунт") {
                                viewModel.openSignUp()
                            }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)

                            Button("Забыли пароль?") {
                                viewModel.isForgotPasswordSheetPresented = true
                                viewModel.errorMessage = nil
                            }
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(AppTheme.Colors.accentBlue)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(AppTheme.Spacing.lg)
                        .background(AppTheme.Colors.surfacePrimary.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                                .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, -AppTheme.Spacing.lg)
                        .padding(.bottom, AppTheme.Spacing.xxl)
                    }
                }
            }
            .navigationTitle("Вход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $viewModel.isForgotPasswordSheetPresented) {
                ForgotPasswordSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isResetPasswordSheetPresented, onDismiss: {
                viewModel.closeResetFlow()
            }) {
                ResetPasswordSheet(viewModel: viewModel)
            }
        }
    }

    private var loginHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(hex: 0x581C87).opacity(0.45),
                    Color(hex: 0x111827),
                    Color(hex: 0x1E3A5F).opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0), Color(hex: 0x07101A)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )

            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                    .padding(12)
                    .background(AppTheme.Colors.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(AppTheme.Colors.accentPrimary.opacity(0.35), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Orda Control")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Вход для сотрудников, операторов и клиентов")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(AppTheme.Spacing.lg)
        }
    }
}

private struct ForgotPasswordSheet: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Введите email аккаунта. Мы отправим ссылку для восстановления пароля.")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                TextField("Email", text: $viewModel.resetEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .appInputStyle()

                if let info = viewModel.resetInfoMessage {
                    Text(info)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.success)
                        .padding(AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.successBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                .stroke(AppTheme.Colors.success.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }

                if let error = viewModel.errorMessage {
                    Text(ServerJSONPlaintext.normalize(error))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.error)
                        .padding(AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.errorBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                .stroke(AppTheme.Colors.errorBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }

                if viewModel.isRecoveringResetLink {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ProgressView().tint(AppTheme.Colors.accentBlue)
                        Text("Проверяем ссылку восстановления…")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.info.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(AppTheme.Colors.info.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }

                Button {
                    Task { await viewModel.sendPasswordResetEmail() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        if viewModel.resetResendCooldown > 0 {
                            Text("Повторно через \(viewModel.resetResendCooldown) сек")
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Отправить ссылку").frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isLoading || viewModel.resetResendCooldown > 0)

                Spacer()
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Восстановление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

private struct ResetPasswordSheet: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Введите новый пароль для аккаунта.")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                SecureField("Новый пароль", text: $viewModel.resetNewPassword)
                    .appInputStyle()
                SecureField("Повторите пароль", text: $viewModel.resetConfirmPassword)
                    .appInputStyle()

                if let error = viewModel.errorMessage {
                    Text(ServerJSONPlaintext.normalize(error))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.error)
                        .padding(AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.errorBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                .stroke(AppTheme.Colors.errorBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }

                Button {
                    Task { await viewModel.applyRecoveredPassword() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Сохранить пароль").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isLoading)

                Spacer()
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Новый пароль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        viewModel.closeResetFlow()
                        dismiss()
                    }
                }
            }
        }
    }
}
