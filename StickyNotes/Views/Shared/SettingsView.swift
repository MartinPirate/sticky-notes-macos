import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultColor") private var defaultColor: String = NoteColor.yellow.rawValue
    @AppStorage("confirmBeforeDelete") private var confirmBeforeDelete: Bool = true
    @AppStorage("followActiveApp") private var followActiveApp: Bool = true

    var body: some View {
        Form {
            Picker("Default note color", selection: $defaultColor) {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    HStack {
                        Circle()
                            .fill(color.background)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                        Text(color.displayName)
                    }
                    .tag(color.rawValue)
                }
            }

            Toggle("Confirm before deleting a note", isOn: $confirmBeforeDelete)
            Toggle("Follow active app window", isOn: $followActiveApp)
                .help("Automatically reposition notes below the active app window")
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 180)
    }
}
