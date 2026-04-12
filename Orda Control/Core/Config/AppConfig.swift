import Foundation

enum AppEnvironment: String {
    case development
    case production
}

struct AppConfig {
    let environment: AppEnvironment
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabaseAnonKey: String
    let passwordResetRedirectURL: String
    /// Публичная витрина (веб), если каталог в API пуст или недоступен. Задаётся `STOREFRONT_URL` в Info.plist или окружении.
    let storefrontURL: String
    let appLockTimeoutSeconds: TimeInterval

    init(
        environment: AppEnvironment,
        apiBaseURL: URL,
        supabaseURL: URL,
        supabaseAnonKey: String,
        passwordResetRedirectURL: String = "orda-control://auth/reset-password",
        storefrontURL: String = "",
        appLockTimeoutSeconds: TimeInterval = 120
    ) {
        self.environment = environment
        self.apiBaseURL = apiBaseURL
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.passwordResetRedirectURL = passwordResetRedirectURL
        self.storefrontURL = storefrontURL
        self.appLockTimeoutSeconds = max(0, appLockTimeoutSeconds)
    }

    static var current: AppConfig {
        #if DEBUG
        let environment: AppEnvironment = .development
        #else
        let environment: AppEnvironment = .production
        #endif

        let apiBaseURLString = value(for: "API_BASE_URL", defaultValue: "https://www.ordaops.kz")
        let supabaseURLString = value(for: "SUPABASE_URL", defaultValue: "https://tmudsqgagblmdctaosgw.supabase.co")
        let supabaseAnonKey = value(for: "SUPABASE_ANON_KEY", defaultValue: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtdWRzcWdhZ2JsbWRjdGFvc2d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0MTM4MjcsImV4cCI6MjA3ODk4OTgyN30.XcIy_NBVFoIjvQ0TynpwV-Ehe12Zq17jaO3bdCgVsgU")
        let passwordResetRedirectURL = value(for: "PASSWORD_RESET_REDIRECT_URL", defaultValue: "orda-control://auth/reset-password")
        let storefrontURL = value(for: "STOREFRONT_URL", defaultValue: "")
        let appLockTimeoutSeconds = TimeInterval(value(for: "APP_LOCK_TIMEOUT_SECONDS", defaultValue: "120")) ?? 120

        return AppConfig(
            environment: environment,
            apiBaseURL: URL(string: apiBaseURLString)!,
            supabaseURL: URL(string: supabaseURLString)!,
            supabaseAnonKey: supabaseAnonKey,
            passwordResetRedirectURL: passwordResetRedirectURL,
            storefrontURL: storefrontURL,
            appLockTimeoutSeconds: appLockTimeoutSeconds
        )
    }

    private static func value(for key: String, defaultValue: String) -> String {
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !infoValue.isEmpty {
            return infoValue
        }
        return defaultValue
    }
}
