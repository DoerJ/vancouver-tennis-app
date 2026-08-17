import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    private let content = PrivacyPolicyContent.loadFromBundle()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(content.title)
                        .font(.rally(size: 32, weight: .bold))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        privacyMetadataRow(
                            title: AppContent.string("terms.effectiveDate"),
                            value: content.effectiveDate
                        )
                        privacyMetadataRow(
                            title: AppContent.string("terms.lastUpdated"),
                            value: content.lastUpdated
                        )
                    }

                    ForEach(content.intro, id: \.self) { paragraph in
                        privacyParagraph(paragraph)
                    }

                    ForEach(content.sections) { section in
                        privacySection(section)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 29)
                .padding(.top, 96)
                .padding(.bottom, 48)
            }

            RallyCircularBackButton {
                dismiss()
            }
            .padding(.leading, 18)
            .padding(.top, 17)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func privacyMetadataRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.rally(size: 13, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            Text(value)
                .font(.rally(size: 13, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
        }
    }

    private func privacySection(_ section: PrivacyPolicySection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title)
                .font(.rally(size: 20, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            ForEach(section.paragraphs, id: \.self) { paragraph in
                privacyParagraph(paragraph)
            }

            ForEach(section.subsections) { subsection in
                privacySubsection(subsection)
            }

            ForEach(section.bullets, id: \.self) { bullet in
                privacyBullet(bullet)
            }

            ForEach(section.bulletGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    privacyParagraph(group.title)

                    ForEach(group.bullets, id: \.self) { bullet in
                        privacyBullet(bullet)
                    }
                }
            }

            ForEach(section.footer, id: \.self) { paragraph in
                privacyParagraph(paragraph)
            }
        }
    }

    private func privacySubsection(_ subsection: PrivacyPolicySubsection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subsection.title)
                .font(.rally(size: 17, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            ForEach(subsection.paragraphs, id: \.self) { paragraph in
                privacyParagraph(paragraph)
            }

            ForEach(subsection.bullets, id: \.self) { bullet in
                privacyBullet(bullet)
            }

            ForEach(subsection.footer, id: \.self) { paragraph in
                privacyParagraph(paragraph)
            }
        }
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.rally(size: 15, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            privacyParagraph(text)
        }
    }

    private func privacyParagraph(_ text: String) -> some View {
        Text(text)
            .font(.rally(size: 15, weight: .medium))
            .foregroundStyle(RallyDiscoverStyle.mutedText)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
