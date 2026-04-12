import SwiftUI
import Combine

// MARK: - Models

struct AIMessage: Identifiable {
    let id = UUID()
    let role: String  // "user" | "assistant"
    let content: String
    let timestamp: Date
}

private struct AIAssistantBody: Encodable {
    let message: String
    let history: [AIHistoryItem]?
}

private struct AIHistoryItem: Encodable {
    let role: String
    let content: String
}

private struct AIAssistantResponse: Decodable {
    let reply: String?
    let answer: String?
    let message: String?
    let data: String?

    var resolved: String { reply ?? answer ?? message ?? data ?? "…" }
}

// MARK: - ViewModel

@MainActor
final class AdminAIAssistantViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var inputText = ""
    @Published var isSending = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var canSend: Bool { !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = AIMessage(role: "user", content: text, timestamp: Date())
        messages.append(userMsg)
        inputText = ""
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let history = messages.dropLast().map { AIHistoryItem(role: $0.role, content: $0.content) }
            let body = AIAssistantBody(message: text, history: history.isEmpty ? nil : Array(history))
            let response: AIAssistantResponse = try await apiClient.request(ContractEndpoint.api_ai_assistant.post, body: body)
            let assistantMsg = AIMessage(role: "assistant", content: response.resolved, timestamp: Date())
            messages.append(assistantMsg)
            AppHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            messages.removeLast()
            AppHaptics.error()
        }
    }

    func clearHistory() {
        messages = []
        errorMessage = nil
    }
}

// MARK: - View

struct AdminAIAssistantView: View {
    @StateObject private var vm: AdminAIAssistantViewModel
    @FocusState private var inputFocused: Bool

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: AdminAIAssistantViewModel(apiClient: apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.messages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(vm.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                            if vm.isSending {
                                thinkingIndicator
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.error)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.xs)
            }

            Divider().background(AppTheme.Colors.borderSubtle)
            inputBar
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("AI Ассистент")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !vm.messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.error)
                    }
                }
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer(minLength: 60)

                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.purpleBg)
                        .frame(width: 88, height: 88)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.Colors.purple)
                }

                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("AI Ассистент")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Задайте вопрос по бизнесу, аналитике\nили управлению")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Попробуйте спросить", icon: "lightbulb.fill", iconColor: AppTheme.Colors.warning)
                    suggestionChip("Покажи топ операторов по производительности")
                    suggestionChip("Проанализируй расходы за этот месяц")
                    suggestionChip("Какие смены были самые прибыльные?")
                    suggestionChip("Предложи способы сократить операционные расходы")
                }
                .padding(AppTheme.Spacing.md)
                .appCard()
                .padding(.horizontal, AppTheme.Spacing.md)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func suggestionChip(_ text: String) -> some View {
        Button {
            vm.inputText = text
            inputFocused = true
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "arrow.up.right.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.purple)
                Text(text)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Message Bubble

    @ViewBuilder
    private func messageBubble(_ msg: AIMessage) -> some View {
        let isUser = msg.role == "user"
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.xs) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.purpleBg)
                        .frame(width: 28, height: 28)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.purple)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                Text(msg.content)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(isUser ? .white : AppTheme.Colors.textPrimary)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(isUser ? AppTheme.Colors.accentPrimary : AppTheme.Colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                            .stroke(isUser ? Color.clear : AppTheme.Colors.borderSubtle, lineWidth: 1)
                    )

                Text(formatTime(msg.timestamp))
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }

            if isUser {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accentPrimary.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
            }
            if !isUser { Spacer(minLength: 50) }
        }
    }

    // MARK: Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.purpleBg)
                    .frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.purple)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppTheme.Colors.textMuted)
                        .frame(width: 6, height: 6)
                        .opacity(0.5)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(AppTheme.Colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            Spacer(minLength: 50)
        }
    }

    // MARK: Input Bar

    private var inputBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField("Спросите AI…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.borderSubtle, lineWidth: 1))
                .onSubmit { Task { await vm.send() } }

            Button {
                Task { await vm.send() }
            } label: {
                ZStack {
                    Circle()
                        .fill(vm.canSend ? AppTheme.Colors.accentPrimary : AppTheme.Colors.bgSecondary)
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(vm.canSend ? .white : AppTheme.Colors.textMuted)
                }
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSend)
            .animation(.easeInOut(duration: 0.15), value: vm.canSend)
        }
        .padding(AppTheme.Spacing.sm)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
