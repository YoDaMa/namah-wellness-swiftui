import SwiftUI

/// Reusable "For you" callout for South Asian personalization content.
/// Warm cream background with leaf icon — appears in meal cards, phase descriptions, workout notes.
struct SACalloutView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FOR YOU")
                .font(.sans(8))
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.spice)
                .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.sans(16))
                    .foregroundStyle(.spice)

                Text(text)
                    .font(.prose(13))
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFFF8F0))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.spice.opacity(0.12), lineWidth: 1)
        )
    }
}
