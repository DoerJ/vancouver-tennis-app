import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    private let content = TermsOfServiceContent.loadFromBundle()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(content.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        termsMetadataRow(
                            title: AppContent.string("terms.effectiveDate"),
                            value: content.effectiveDate
                        )
                        termsMetadataRow(
                            title: AppContent.string("terms.lastUpdated"),
                            value: content.lastUpdated
                        )
                    }

                    ForEach(content.intro, id: \.self) { paragraph in
                        termsParagraph(paragraph)
                    }

                    ForEach(content.sections) { section in
                        termsSection(section)
                    }
                }
                .padding(.horizontal, 29)
                .padding(.top, 96)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func termsMetadataRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
        }
    }

    private func termsSection(_ section: TermsOfServiceSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            ForEach(section.paragraphs, id: \.self) { paragraph in
                termsParagraph(paragraph)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.bullets, id: \.self) { bullet in
                    termsBullet(bullet)
                }
            }

            ForEach(section.bulletGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    termsParagraph(group.title)

                    ForEach(group.bullets, id: \.self) { bullet in
                        termsBullet(bullet)
                    }
                }
            }

            ForEach(section.footer, id: \.self) { paragraph in
                termsParagraph(paragraph)
            }
        }
    }

    private func termsBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            termsParagraph(text)
        }
    }

    private func termsParagraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(RallyDiscoverStyle.mutedText)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
