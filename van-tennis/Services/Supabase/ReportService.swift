import Foundation
import Supabase

struct ReportService {
    private let client = SupabaseClientProvider.shared

    func createReports(_ reports: [NewReport]) async throws -> [Report] {
        guard !reports.isEmpty else {
            return []
        }

        return try await client
            .from("reports")
            .insert(reports)
            .select()
            .execute()
            .value
    }
}
