import SwiftUI

struct QiGongResourcesSheet: View {
    var isSheet: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if isSheet {
            NavigationStack {
                qiGongContent
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        } else {
            qiGongContent
                .navigationBarBackButtonHidden()
                .toolbar(.hidden, for: .tabBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.black, .white)
                        }
                    }
                }
        }
    }

    private var qiGongContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Qi Gong Resources")
                        .font(.display(22, relativeTo: .title3))

                    Text("Gentle energy work that complements your cycle. These sessions by QiYoga With LuChin pair well with any phase.")
                        .font(.prose(13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    ForEach(Array(Self.videos.enumerated()), id: \.element.id) { index, video in
                        Link(destination: video.url) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .font(.sans(24))
                                    .foregroundStyle(.phaseF)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(video.title)
                                        .font(.nSubheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)

                                    Text(video.subtitle)
                                        .font(.nCaption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.nCaption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }

                        if index < Self.videos.count - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Qi Gong")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Data

private struct QiGongVideo: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: URL
}

extension QiGongResourcesSheet {
    fileprivate static let videos: [QiGongVideo] = [
        QiGongVideo(
            title: "Spring Rejuvenation Qigong",
            subtitle: "Seasonal renewal flow for energy and clarity",
            url: URL(string: "https://www.youtube.com/watch?v=smYpJZR8pOs&t=287s")!
        ),
        QiGongVideo(
            title: "Release Negative Emotions",
            subtitle: "Let go of tension and emotional stagnation",
            url: URL(string: "https://www.youtube.com/watch?v=9fnmwb09bHM")!
        ),
        QiGongVideo(
            title: "Morning Lymphatic Flow",
            subtitle: "Gentle morning practice to activate lymph drainage",
            url: URL(string: "https://www.youtube.com/watch?v=0gTJ_eBZy7g")!
        ),
        QiGongVideo(
            title: "Advanced Lymphatic Flow",
            subtitle: "Deeper lymphatic work for experienced practitioners",
            url: URL(string: "https://www.youtube.com/watch?v=FXXSf2TPr2g")!
        ),
        QiGongVideo(
            title: "Morning Detox Qigong",
            subtitle: "Start the day with cleansing breath and movement",
            url: URL(string: "https://www.youtube.com/watch?v=7RfMrjA8qYM&t=8s")!
        ),
    ]
}
