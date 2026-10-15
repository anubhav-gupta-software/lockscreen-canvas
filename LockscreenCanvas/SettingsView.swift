import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var remoteURL = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    TextField("https://your-project-default-rtdb.firebaseio.com", text: $remoteURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Database")
                } footer: {
                    Text("Leave this empty to keep the canvas on this iPhone. Paste the root of a Firebase Realtime Database to sync with another phone. Setup is in the README, and you don’t need an API key.")
                }
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Section("On this iPhone") {
                    LabeledContent("Sync", value: model.isRemoteSync ? "Between phones" : "This iPhone")
                    LabeledContent("Lock Screen", value: AppGroup.isAvailable ? "Sharing the canvas" : "Needs a paid account")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.desk)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear {
                name = model.profile.displayName
                remoteURL = model.profile.remoteURL
            }
        }
    }

    private func save() {
        if let message = model.updateRemoteURL(remoteURL) {
            error = message
            return
        }
        model.updateDisplayName(name)
        dismiss()
    }
}
