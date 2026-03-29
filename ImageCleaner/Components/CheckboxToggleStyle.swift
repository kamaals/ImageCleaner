import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(.primary, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if configuration.isOn {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(.primary)
                            .frame(width: 10, height: 10)
                    }
                }
                .accessibilityHidden(true)

                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "checked" : "unchecked")
    }
}
