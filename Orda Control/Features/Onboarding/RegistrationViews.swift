import SwiftUI

// MARK: - Shared onboarding chrome

private struct OnboardingHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(hex: 0x581C87).opacity(0.4),
                    Color(hex: 0x111827),
                    Color(hex: 0x1E3A5F).opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0), Color(hex: 0x07101A)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )

            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.purple)
                    .padding(11)
                    .background(AppTheme.Colors.purpleBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(AppTheme.Colors.purpleBorder, lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.Typography.title3)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
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

// MARK: - Screens

struct RegistrationStartView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onSwitchToLogin: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        OnboardingHeader(
                            title: "Новый аккаунт",
                            subtitle: "Укажите email и пароль для регистрации клиента",
                            systemImage: "person.badge.plus.fill"
                        )

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            TextField("Введите email", text: $viewModel.signUpEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .appInputStyle()

                            SecureField("Введите пароль", text: $viewModel.signUpPassword)
                                .appInputStyle()

                            SecureField("Подтверждение пароля", text: $viewModel.confirmPassword)
                                .appInputStyle()

                            if let error = viewModel.errorMessage {
                                Text(ServerJSONPlaintext.normalize(error))
                                    .foregroundStyle(AppTheme.Colors.error)
                                    .font(AppTheme.Typography.caption)
                                    .padding(AppTheme.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.Colors.errorBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                            .stroke(AppTheme.Colors.errorBorder, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            }

                            Button("Создать аккаунт") {
                                Task { await viewModel.signUp() }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(viewModel.isLoading)

                            Button("Уже есть аккаунт? Войти") {
                                onSwitchToLogin()
                            }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)
                        }
                        .padding(AppTheme.Spacing.lg)
                        .background(AppTheme.Colors.surfacePrimary.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                                .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, -AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.xxl)
                    }
                }
                .overlay {
                    if viewModel.isLoading {
                        LoadingStateView(message: "Создание аккаунта...")
                    }
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct EmailConfirmationView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var viewModel: RegistrationViewModel
    let email: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        OnboardingHeader(
                            title: "Подтвердите email",
                            subtitle: "Перейдите по ссылке из письма, затем продолжите регистрацию",
                            systemImage: "envelope.badge.fill"
                        )

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("Мы отправили письмо на адрес:")
                                .font(AppTheme.Typography.callout)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            SecondaryChip(text: email, color: AppTheme.Colors.info)

                            AlertBanner(
                                message: "Проверьте папку «Спам» и «Промоакции», если письма нет во входящих.",
                                style: .info
                            )

                            if let info = viewModel.infoMessage {
                                Text(info)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.success)
                                    .padding(AppTheme.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.Colors.successBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                            .stroke(AppTheme.Colors.successBorder, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            }
                            if let error = viewModel.errorMessage {
                                Text(ServerJSONPlaintext.normalize(error))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.error)
                            }

                            Button("Проверить подтверждение") {
                                Task { await viewModel.checkConfirmation() }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(viewModel.isLoading)

                            Button(viewModel.resendCooldown > 0 ? "Повторная отправка через \(viewModel.resendCooldown) с" : "Отправить письмо повторно") {
                                Task { await viewModel.resendConfirmation() }
                            }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)
                            .disabled(viewModel.isLoading || viewModel.resendCooldown > 0)

                            Button("На экран входа") {
                                sessionStore.backToSignIn()
                            }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)
                        }
                        .padding(AppTheme.Spacing.lg)
                        .background(AppTheme.Colors.surfacePrimary.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                                .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, -AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.xxl)
                    }
                }
                .overlay {
                    if viewModel.isLoading {
                        LoadingStateView(message: "Загрузка...")
                    }
                }
            }
            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        sessionStore.backToSignIn()
                    } label: {
                        Label("К входу", systemImage: "chevron.left")
                    }
                }
            }
        }
    }
}

struct RegistrationDetailsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var viewModel: RegistrationViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        OnboardingHeader(
                            title: "Завершение регистрации",
                            subtitle: "Телефон и компания обязательны. Точку можно не выбирать — брони и станции будут доступны по сети.",
                            systemImage: "person.text.rectangle.fill"
                        )

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            SectionHeader(title: "Компания и точка (по желанию)", icon: "building.2.fill", iconColor: AppTheme.Colors.purple)
                            if viewModel.registrationCompanies.isEmpty {
                                Text("Загрузите список компаний — кнопка ниже или экран откроется с автозагрузкой.")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            } else {
                                Picker("Компания", selection: $viewModel.selectedCompanyId) {
                                    Text("Выберите компанию").tag("")
                                    ForEach(viewModel.registrationCompanies) { co in
                                        Text(co.name).tag(co.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .appInputStyle()
                            }
                            if !viewModel.selectedCompanyId.isEmpty {
                                let pts = viewModel.pointsForSelectedCompany
                                if pts.isEmpty {
                                    Text("Для этой компании нет доступных точек в справочнике.")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.warning)
                                } else {
                                    Picker("Точка (проект)", selection: $viewModel.selectedPointProjectId) {
                                        Text("Не указывать — по всей сети").tag("")
                                        ForEach(pts) { pt in
                                            Text(pt.name).tag(pt.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .appInputStyle()
                                }
                            }

                            SectionHeader(title: "Контакты", icon: "phone.fill", iconColor: AppTheme.Colors.info)

                            TextField("Телефон", text: $viewModel.phone)
                                .keyboardType(.phonePad)
                                .appInputStyle()

                            TextField("Имя (необязательно)", text: $viewModel.name)
                                .appInputStyle()

                            if let error = viewModel.errorMessage {
                                Text(ServerJSONPlaintext.normalize(error))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.error)
                                    .padding(AppTheme.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.Colors.errorBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                            .stroke(AppTheme.Colors.errorBorder, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            }

                            Button("Загрузить компании и точки") {
                                Task { await viewModel.loadRegistrationCatalog() }
                            }
                            .buttonStyle(GhostButtonStyle())

                            Button("Завершить регистрацию") {
                                Task { await viewModel.completeRegistration() }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(
                                viewModel.isLoading
                                    || viewModel.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || viewModel.selectedCompanyId.isEmpty
                            )

                            Button("Выйти из аккаунта") {
                                Task { await sessionStore.logout(clearMessage: true) }
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                        .padding(AppTheme.Spacing.lg)
                        .background(AppTheme.Colors.surfacePrimary.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                                .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, -AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.xxl)
                    }
                }
                .overlay {
                    if viewModel.isLoading {
                        LoadingStateView(message: "Сохранение...")
                    }
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if viewModel.registrationCompanies.isEmpty {
                    await viewModel.loadRegistrationCatalog()
                }
            }
            .onChange(of: viewModel.selectedCompanyId) { _, _ in
                viewModel.selectedPointProjectId = ""
                let pts = viewModel.pointsForSelectedCompany
                if pts.count == 1 {
                    viewModel.selectedPointProjectId = pts[0].id
                }
            }
        }
    }
}
