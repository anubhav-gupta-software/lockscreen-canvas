import SwiftUI

struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("The same drawing can sit under the clock, in a Lock Screen complication, and on the Home Screen.")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    stepGroup(title: "Lock Screen") {
                        step(1, "Touch and hold the Lock Screen, then tap Customize.")
                        step(2, "Tap the widget area under the clock, or a circular complication.")
                        step(3, "Search for Doodl and add it.")
                    }

                    stepGroup(title: "Home Screen") {
                        step(1, "Touch and hold the Home Screen until the icons jiggle.")
                        step(2, "Tap the + button, then search for Doodl.")
                        step(3, "Choose small, medium, or large.")
                    }

                    if AppGroup.isAvailable {
                        Text("Drawing in the app updates the widgets. If one looks stale, open the app once.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The widget is on this iPhone, but it can’t read the drawing yet.")
                                .font(.subheadline.weight(.medium))
                            Text("Sharing needs an App Group, which Apple only allows with a paid Developer Program membership. Run the “LockscreenCanvas Shared” scheme after you enroll. Until then, both of you still see the drawing inside the app.")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(24)
            }
            .background(Theme.desk)
            .navigationTitle("Add the widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func stepGroup(title: String, @ViewBuilder steps: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Theme.ink)
            steps()
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.paper)
                .frame(width: 26, height: 26)
                .background(Theme.ink)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
