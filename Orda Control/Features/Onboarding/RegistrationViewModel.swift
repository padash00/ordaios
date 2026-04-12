import Foundation
import Combine

@MainActor
final class RegistrationViewModel: ObservableObject {
    @Published var signUpEmail = ""
    @Published var signUpPassword = ""
    @Published var confirmPassword = ""
    @Published var phone = ""
    @Published var name = ""
    @Published var registrationCompanies: [RegistrationCompany] = []
    @Published var registrationPoints: [RegistrationPoint] = []
    @Published var selectedCompanyId: String = ""
    @Published var selectedPointProjectId: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let sessionStore: SessionStore

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var resendCooldown: Int { sessionStore.resendCooldown }

    func signUp() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await sessionStore.signUp(email: signUpEmail, password: signUpPassword, confirmPassword: confirmPassword)
            infoMessage = "Проверьте email для подтверждения."
        } catch {
            errorMessage = OnboardingErrorMapper.message(from: error)
        }
    }

    func checkConfirmation() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await sessionStore.checkEmailConfirmation()
        } catch {
            errorMessage = OnboardingErrorMapper.message(from: error)
        }
    }

    func resendConfirmation() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await sessionStore.resendConfirmationEmail()
            infoMessage = "Письмо отправлено повторно."
            AppHaptics.success()
        } catch {
            errorMessage = OnboardingErrorMapper.message(from: error)
            AppHaptics.error()
        }
    }

    var pointsForSelectedCompany: [RegistrationPoint] {
        guard !selectedCompanyId.isEmpty else { return [] }
        return registrationPoints.filter { $0.companyIds.contains(selectedCompanyId) }
    }

    /// Публичный справочник компаний и точек (нужен до `completeCustomerRegistration`, т.к. бэкенд требует `companyCode` и uuid точки).
    func loadRegistrationCatalog() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let opts = try await sessionStore.loadRegistrationOptions()
            registrationCompanies = opts.companies
            registrationPoints = opts.points
            if selectedCompanyId.isEmpty, registrationCompanies.count == 1 {
                selectedCompanyId = registrationCompanies[0].id
            }
            if selectedPointProjectId.isEmpty, pointsForSelectedCompany.count == 1 {
                selectedPointProjectId = pointsForSelectedCompany[0].id
            }
        } catch {
            errorMessage = OnboardingErrorMapper.message(from: error)
        }
    }

    func completeRegistration() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let company = registrationCompanies.first(where: { $0.id == selectedCompanyId }) else {
            errorMessage = "Выберите компанию из списка."
            return
        }
        let code = company.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 2 else {
            errorMessage = "У выбранной компании нет кода для регистрации."
            return
        }
        let pointId = selectedPointProjectId.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await sessionStore.completeCustomerRegistration(
                companyCode: code,
                pointProjectId: pointId.isEmpty ? nil : pointId,
                phone: phone,
                name: name
            )
        } catch {
            errorMessage = OnboardingErrorMapper.message(from: error)
        }
    }
}
