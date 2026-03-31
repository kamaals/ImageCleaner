import SwiftUI

struct ResultCategoryRow<Icon: View>: View {
    let icon: Icon
    let title: String
    let itemCount: Int
    let size: String
    var foreground: Color = .primary

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            icon
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.jost(size: 20, weight: 500))
                    .foregroundStyle(foreground)

                HStack(spacing: 8) {
                    Text("\(itemCount) items")
                        .font(AppFont.jost(size: 14, weight: 400))
                    Circle()
                        .fill(.secondary)
                        .frame(width: 4, height: 4)
                    Text(size)
                        .font(AppFont.jost(size: 14, weight: 400))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
