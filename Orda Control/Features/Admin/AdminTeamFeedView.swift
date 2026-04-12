import SwiftUI

// MARK: - Service

protocol AdminTeamFeedServicing {
    func loadFeed() async throws -> [FeedPost]
    func createPost(content: String) async throws
    func likePost(postId: String) async throws
}

final class AdminTeamFeedService: AdminTeamFeedServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadFeed() async throws -> [FeedPost] {
        let response: DataListResponse<FeedPost> = try await apiClient.request(ContractEndpoint.api_admin_feed.get)
        return response.data
    }

    func createPost(content: String) async throws {
        let payload = FeedCreatePayload(content: content)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_feed.post, body: payload)
    }

    func likePost(postId: String) async throws {
        struct LikePayload: Encodable { let post_id: String }
        let endpoint = APIEndpoint(path: ContractEndpoint.api_admin_feed.rawValue + "/like", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: LikePayload(post_id: postId))
    }
}

// MARK: - ViewModel

@MainActor
final class AdminTeamFeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false
    @Published var isPosting = false
    @Published var errorMessage: String?
    @Published var showCompose = false
    @Published var composeContent = ""
    @Published var likedPostIds: Set<String> = []

    var isAdmin: Bool

    private let service: AdminTeamFeedServicing

    init(service: AdminTeamFeedServicing, isAdmin: Bool = true) {
        self.service = service
        self.isAdmin = isAdmin
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            posts = try await service.loadFeed()
        } catch {
            posts = []
            let apiErr = error as? APIError
            // 404 / not deployed — show empty state silently
            if apiErr != .invalidResponse && apiErr != .decodingFailed {
                errorMessage = nil // graceful empty state
            }
        }
    }

    func publish() async {
        guard !composeContent.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await service.createPost(content: composeContent)
            composeContent = ""
            showCompose = false
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось опубликовать"
            AppHaptics.error()
        }
    }

    func like(post: FeedPost) async {
        likedPostIds.insert(post.id)
        do {
            try await service.likePost(postId: post.id)
            AppHaptics.impact()
        } catch {
            likedPostIds.remove(post.id)
        }
    }
}

// MARK: - View

struct AdminTeamFeedView: View {
    let apiClient: APIClient
    var isAdmin: Bool = true

    @StateObject private var vm: AdminTeamFeedViewModel

    init(apiClient: APIClient, isAdmin: Bool = true) {
        self.apiClient = apiClient
        self.isAdmin = isAdmin
        _vm = StateObject(wrappedValue: AdminTeamFeedViewModel(
            service: AdminTeamFeedService(apiClient: apiClient),
            isAdmin: isAdmin
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.bgPrimary.ignoresSafeArea()

            if vm.isLoading {
                LoadingStateView(message: "Загрузка ленты…")
            } else if vm.posts.isEmpty {
                EmptyStateView(message: "Нет публикаций в ленте", icon: "text.bubble")
            } else {
                feedList
            }
        }
        .navigationTitle("Лента")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accentPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showCompose) {
            composeSheet
        }
        .task { await vm.load() }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.sm) {
                ForEach(vm.posts) { post in
                    postCard(post)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private func postCard(_ post: FeedPost) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName ?? "Администратор")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                    Text(formatDate(post.createdAt))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                Button {
                    Task { await vm.like(post: post) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vm.likedPostIds.contains(post.id) ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(vm.likedPostIds.contains(post.id) ? AppTheme.Colors.error : AppTheme.Colors.textMuted)
                        Text("\(post.likesCount + (vm.likedPostIds.contains(post.id) ? 1 : 0))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                .buttonStyle(.plain)
            }

            Text(post.content)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                } placeholder: {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .fill(AppTheme.Colors.surfaceSecondary)
                        .frame(height: 180)
                }
            }
        }
        .appCard()
    }

    private var composeSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.bgPrimary.ignoresSafeArea()
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Напишите что-нибудь для команды")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textMuted)

                    TextEditor(text: $vm.composeContent)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(AppTheme.Colors.surfaceSecondary)
                        .frame(minHeight: 180)
                        .padding(AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.borderSubtle, lineWidth: 1))

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                    }

                    Spacer()

                    Button {
                        Task { await vm.publish() }
                    } label: {
                        HStack {
                            if vm.isPosting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Опубликовать")
                            }
                        }
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.info)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                    }
                    .disabled(vm.isPosting || vm.composeContent.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(vm.composeContent.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                }
                .padding(AppTheme.Spacing.md)
            }
            .navigationTitle("Новая публикация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { vm.showCompose = false }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            display.locale = Locale(identifier: "ru_RU")
            return display.string(from: date)
        }
        return dateStr
    }
}
