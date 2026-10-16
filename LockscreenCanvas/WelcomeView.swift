import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var name = ""
    @State private var showJoin = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                    .tint(Theme.ink)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Doodl")
                        .font(.system(size: 46, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text("A page for two. What you draw shows up on their Lock Screen.")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PageCard(document: SampleCanvas.preview())
                    .frame(maxWidth: 280)
                    .frame(maxWidth: .infinity)

                TextField("Your name", text: $name)
                    .font(.system(.body, design: .serif))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(14)
                    .background(Theme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onSubmit(start)

                Button(action: start) {
                    Text("Start a Doodl")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ink)
                .disabled(model.isBusy)

                Button {
                    model.updateDisplayName(name)
                    showJoin = true
                } label: {
                    Text("Join with a code")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .tint(Theme.ink)

                Text(model.isRemoteSync
                     ? "Sync is on. A code works from another phone."
                     : "Saved on this iPhone until you add a database in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let error = model.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
        .background(Theme.desk)
        .onAppear {
            if name.isEmpty {
                name = model.profile.displayName
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func start() {
        model.updateDisplayName(name)
        Task { await model.createCanvas() }
    }
}

struct JoinSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ask them for the code on their Doodl.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("ABC-123", text: $code)
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(Theme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onSubmit(join)

                if let error = model.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.desk)
            .navigationTitle("Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join", action: join)
                        .disabled(model.isBusy || InviteCode.normalize(code).count < InviteCode.length)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func join() {
        Task {
            await model.join(rawCode: code)
            if model.session != nil {
                dismiss()
            }
        }
    }
}
