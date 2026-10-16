import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isDrawing = false
    @State private var showGuide = false
    @State private var showSettings = false
    @State private var confirmLeave = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Button {
                    isDrawing = true
                } label: {
                    PageCard(document: model.document)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open the drawing")

                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isRemoteSync ? Theme.accent : Theme.secondary)
                        .frame(width: 8, height: 8)
                    Text(model.statusLine)
                    Spacer(minLength: 8)
                    Text(model.document.updatedAt, style: .relative)
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)

                Button {
                    isDrawing = true
                } label: {
                    Text("Draw")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ink)

                Button {
                    showGuide = true
                } label: {
                    Label("Put it on the Lock Screen", systemImage: "lock.iphone")
                        .font(.system(.body, design: .serif).weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(Theme.ink)

                if !AppGroup.isAvailable {
                    sharingNote
                }

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
        .fullScreenCover(isPresented: $isDrawing) {
            EditorView(document: model.document)
        }
        .sheet(isPresented: $showGuide) {
            WidgetGuideView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Leave this Doodl?",
            isPresented: $confirmLeave,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) { model.leave() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The drawing stays with them. You can join again with the code.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Doodl")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondary)
                Text(InviteCode.formatted(model.session?.code ?? ""))
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Button(action: copyCode) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(copied ? "Copied" : "Copy code")

                ShareLink(item: model.shareMessage) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share code")

                Menu {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                    Button("How to add the widget", systemImage: "lock.iphone") { showGuide = true }
                    Button("Leave this Doodl", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        confirmLeave = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("More")
            }
            .font(.body.weight(.medium))
            .tint(Theme.ink)
        }
    }

    private var sharingNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The widget is installed, but it can’t see this drawing yet.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
            Text("iOS only shares a Doodl with the Lock Screen through an App Group, and that needs a paid Apple Developer account. The README explains how to turn it on. Two phones can still sync in the app once a database URL is set.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func copyCode() {
        UIPasteboard.general.string = model.session?.code ?? ""
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
