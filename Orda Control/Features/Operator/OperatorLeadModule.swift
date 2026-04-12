import Foundation
import Combine
import SwiftUI

// MARK: - API models

struct OperatorLeadPayload: Decodable {
    let ok: Bool?
    let lead: OperatorLeadContext?
    let companies: [OperatorLeadCompanyCard]?
    let teamAssignments: [OperatorLeadTeamAssignment]?
    let tasks: [OperatorLeadPointTask]?
    let requests: [OperatorLeadShiftRequest]?
}

struct OperatorLeadContext: Decodable {
    let operatorInfo: OperatorSalaryOperatorBrief?
    let assignments: [OperatorLeadAssignmentRow]?

    private enum CodingKeys: String, CodingKey {
        case assignments
        case operatorInfo = "operator"
    }
}

struct OperatorLeadAssignmentRow: Decodable, Identifiable {
    let id: String
    let companyId: String?
    let companyName: String?
    let companyCode: String?
    let roleInCompany: String?
}

struct OperatorLeadCompanyCard: Decodable, Identifiable {
    let id: String
    let name: String?
    let code: String?
    let leadRole: String?
    let publication: OperatorLeadPublicationLite?
    let weeklyStatus: OperatorLeadWeeklyStatus?
}

struct OperatorLeadPublicationLite: Decodable {
    let id: String?
    let companyId: String?
    let weekStart: String?
    let weekEnd: String?
    let version: Int?
    let status: String?
    let publishedAt: String?
}

struct OperatorLeadWeeklyStatus: Decodable {
    let state: String?
    let total: Int?
    let confirmed: Int?
    let pending: Int?
    let issues: Int?
    let proposals: Int?
    let resolved: Int?
}

struct OperatorLeadTeamAssignment: Decodable, Identifiable {
    let id: String
    let operatorId: String?
    let companyId: String?
    let roleInCompany: String?
    let isPrimary: Bool?
    let isActive: Bool?
    let notes: String?
    let operatorName: String?
}

struct OperatorLeadPointTask: Decodable, Identifiable {
    let id: String
    let taskNumber: Int?
    let title: String?
    let description: String?
    let status: String?
    let priority: String?
    let dueDate: String?
    let operatorId: String?
    let companyId: String?
    let createdAt: String?
    let updatedAt: String?
    let operatorName: String?
    let companyName: String?
    let companyCode: String?
}

struct OperatorLeadShiftRequest: Decodable, Identifiable {
    let id: String
    let publicationId: String?
    let companyId: String?
    let operatorId: String?
    let shiftDate: String?
    let shiftType: String?
    let status: String?
    let source: String?
    let reason: String?
    let leadStatus: String?
    let leadAction: String?
    let leadNote: String?
    let resolutionNote: String?
    let operatorName: String?
    let companyName: String?
    let companyCode: String?
}

// MARK: - View model

@MainActor
final class OperatorLeadViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var payload: OperatorLeadPayload?

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            payload = try await service.fetchOperatorLead()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
        }
    }

    func submitProposal(
        requestId: String,
        action: String,
        note: String?,
        replacementOperatorId: String?
    ) async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.submitLeadShiftProposal(
                requestId: requestId,
                proposalAction: action,
                proposalNote: note,
                replacementOperatorId: replacementOperatorId
            )
            infoMessage = "Решение по заявке отправлено."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось отправить."
            AppHaptics.error()
        }
    }

    func updateTaskStatus(taskId: String, status: String, note: String?) async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.updateLeadPointTask(taskId: taskId, status: status, note: note)
            infoMessage = "Статус задачи обновлён."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось обновить задачу."
            AppHaptics.error()
        }
    }

    func replacementCandidates(for request: OperatorLeadShiftRequest) -> [OperatorLeadTeamAssignment] {
        guard let cid = request.companyId else { return [] }
        let oid = request.operatorId
        return payload?.teamAssignments?.filter { row in
            row.companyId == cid && row.operatorId != nil && row.operatorId != oid
        } ?? []
    }
}
