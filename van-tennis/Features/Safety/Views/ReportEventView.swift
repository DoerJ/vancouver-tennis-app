import SwiftUI

struct ReportEventView: View {
    @Binding var selectedReasons: Set<ReportReason>
    @Binding var selectedReportedUserIDs: Set<UUID>
    @Binding var reportDescription: String
    @FocusState private var isDetailsFocused: Bool

    let errorMessage: String?
    let isSubmitting: Bool
    let reportableProfiles: [UserProfile]
    let currentUserID: UUID?
    let onSubmit: () async -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header

                sectionTitle(AppContent.string("events.detail.reportWho"))
                    .padding(.top, 66)

                reportablePlayersSection
                    .padding(.top, 28)

                sectionTitle(AppContent.string("events.detail.reportReason"))
                    .padding(.top, 36)

                reasonsSection
                    .padding(.top, 22)

                sectionTitle(AppContent.string("events.detail.reportDetails"))
                    .padding(.top, 34)

                detailsCard
                    .padding(.top, 18)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.rally(size: 13, weight: .semibold))
                        .foregroundStyle(RallyDiscoverStyle.redBadge)
                        .padding(.top, 16)
                }

                submitButton
                    .padding(.top, 34)
            }
            .padding(.horizontal, 29)
            .padding(.top, 82)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .onChange(of: reportDescription) { _, newValue in
            guard isDetailsFocused, newValue.hasSuffix("\n") else {
                return
            }

            reportDescription = String(newValue.dropLast()).trimmingCharacters(in: .newlines)
            isDetailsFocused = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button(AppContent.string("common.done")) {
                    isDetailsFocused = false
                }
                .font(.rally(size: 16, weight: .semibold))
            }
        }
    }

    private var header: some View {
        Text(AppContent.string("events.detail.reportEvent"))
            .font(.rally(size: 32, weight: .bold))
            .foregroundStyle(RallyDiscoverStyle.ink)
    }

    private var submitButton: some View {
        Button {
            Task {
                await onSubmit()
            }
        } label: {
            Text(isSubmitting ? AppContent.string("events.detail.submitting") : AppContent.string("events.detail.submit"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(RallyPrimaryActionButtonStyle(isEnabled: canSubmit, showsShadow: true))
        .disabled(!canSubmit)
    }

    private var reportablePlayersSection: some View {
        Group {
            if reportableProfiles.isEmpty {
                Text(AppContent.string("events.detail.noReportablePlayers"))
                    .font(.rally(size: 15, weight: .medium))
                    .foregroundStyle(RallyDiscoverStyle.mutedText)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(reportableProfiles, id: \.id) { profile in
                        reportProfileChip(profile)
                    }
                }
            }
        }
    }

    private func reportProfileChip(_ profile: UserProfile) -> some View {
        let isCurrentUser = profile.id == currentUserID
        let isSelected = selectedReportedUserIDs.contains(profile.id)

        return Button {
            guard !isCurrentUser else {
                return
            }

            if isSelected {
                selectedReportedUserIDs.remove(profile.id)
            } else {
                selectedReportedUserIDs.insert(profile.id)
            }
        } label: {
            Text(profile.displayName)
                .font(.rally(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 28)
                .frame(maxWidth: .infinity)
                .background(
                    (isSelected ? RallyDiscoverStyle.primaryGreen : RallyDiscoverStyle.accentGreen)
                        .opacity(isCurrentUser ? 0.45 : 1),
                    in: Capsule()
                )
                .overlay(alignment: .trailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.rally(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.trailing, 10)
                    }
                }
                .shadow(color: RallyDiscoverStyle.shadow.opacity(isCurrentUser ? 0 : 1), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isCurrentUser)
    }

    private var reasonsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(ReportReason.allCases.enumerated()), id: \.element.id) { index, reason in
                reportReasonRow(reason)

                if index < ReportReason.allCases.count - 1 {
                    reportDivider
                }
            }
        }
    }

    private func reportReasonRow(_ reason: ReportReason) -> some View {
        Button {
            if selectedReasons.contains(reason) {
                selectedReasons.remove(reason)
            } else {
                selectedReasons.insert(reason)
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                Text(reason.displayName)
                    .font(.rally(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                checkbox(isSelected: selectedReasons.contains(reason))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }

    private func checkbox(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isSelected ? RallyDiscoverStyle.accentGreen : Color.white)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.rally(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.black, lineWidth: 1.5)
                }
            }
            .frame(width: 21, height: 21)
    }

    private var detailsCard: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $reportDescription)
                .font(.rally(size: 15, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .scrollContentBackground(.hidden)
                .submitLabel(.done)
                .focused($isDetailsFocused)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            if reportDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(AppContent.string("events.detail.reportDetailsPlaceholder"))
                    .font(.rally(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.30))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 154)
        .background(RallyDiscoverStyle.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: RallyDiscoverStyle.shadow.opacity(0.95), radius: 18, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var reportDivider: some View {
        RallyDivider(horizontalPadding: 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.rally(size: 16, weight: .bold))
            .foregroundStyle(RallyDiscoverStyle.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSubmit: Bool {
        !isSubmitting && !selectedReportedUserIDs.isEmpty && !selectedReasons.isEmpty
    }
}
