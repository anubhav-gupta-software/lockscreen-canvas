import SwiftUI

private struct TextDraft: Identifiable {
    var id = UUID()
    var point: StrokePoint
    var existing: TextItem?
}

struct EditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var drawing: DrawingModel
    @State private var tool: EditorTool = .pen
    @State private var color: BrushColor = .ink
    @State private var size: BrushSize = .medium
    @State private var draft: TextDraft?
    @State private var confirmClear = false
    @State private var notice: String?
    @State private var feedback = 0

    init(document: CanvasDocument) {
        _drawing = State(initialValue: DrawingModel(document: document))
    }

    var body: some View {
        ZStack {
            Theme.desk.ignoresSafeArea()
            DrawingCanvasView(
                document: drawing.document,
                tool: tool,
                colorHex: color.rawValue,
                width: size.rawValue,
                canDraw: !drawing.isPageFull,
                onStroke: { points in
                    if drawing.addStroke(points: points, colorHex: color.rawValue, width: size.rawValue) {
                        notice = nil
                        commit()
                    } else {
                        notice = "This page is full. Erase or clear something to keep drawing."
                    }
                },
                onEraseBegan: { drawing.beginErase() },
                onErase: { point, radius in
                    drawing.erase(at: point, radius: radius)
                },
                onEraseEnded: {
                    drawing.endErase()
                    notice = nil
                    commit()
                },
                onTextTap: { point, existing in
                    draft = TextDraft(point: existing.map { StrokePoint(x: $0.x, y: $0.y) } ?? point, existing: existing)
                },
                onTextMoveChanged: { original, point in
                    drawing.moveText(id: original.id, to: point)
                },
                onTextMoveEnded: { original in
                    drawing.commitTextMove(id: original.id, before: original)
                    commit()
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { dock }
        .sensoryFeedback(.selection, trigger: feedback)
        .confirmationDialog("Clear the page?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                drawing.clear()
                notice = nil
                commit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can undo this.")
        }
        .sheet(item: $draft) { draft in
            TextComposer(
                title: draft.existing == nil ? "Add text" : "Edit text",
                initial: draft.existing?.text ?? "",
                canDelete: draft.existing != nil,
                onSave: { text in
                    if let existing = draft.existing {
                        if drawing.updateText(id: existing.id, text: text) {
                            commit()
                        }
                    } else if drawing.addText(text, at: draft.point, colorHex: color.rawValue, fontSize: size.textSize) {
                        notice = nil
                        commit()
                    } else {
                        notice = "That text didn’t fit."
                    }
                },
                onDelete: {
                    if let existing = draft.existing {
                        drawing.deleteText(id: existing.id)
                        commit()
                    }
                }
            )
        }
        .onChange(of: model.remoteTick) { _, _ in
            drawing.integrateRemote(model.document)
        }
        .onDisappear {
            model.applyLocal(drawing.document)
            Task { await model.flush() }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button("Done", action: finish)
                .font(.system(.body, design: .serif).weight(.semibold))
            Spacer()
            barButton("arrow.uturn.backward", label: "Undo", enabled: drawing.canUndo) {
                drawing.undo()
                commit()
            }
            barButton("arrow.uturn.forward", label: "Redo", enabled: drawing.canRedo) {
                drawing.redo()
                commit()
            }
            barButton("trash", label: "Clear", enabled: true) {
                confirmClear = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.desk)
        .tint(Theme.ink)
    }

    private var dock: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(EditorTool.allCases) { item in
                    Button {
                        tool = item
                    } label: {
                        Label(item.title, systemImage: item.symbol)
                            .labelStyle(.iconOnly)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(tool == item ? Theme.ink : Color.clear)
                            .foregroundStyle(tool == item ? Theme.paper : Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel(item.title)
                }
            }
            .padding(4)
            .background(Theme.desk)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if tool != .eraser {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(BrushColor.allCases) { swatch in
                            Button {
                                color = swatch
                            } label: {
                                Circle()
                                    .fill(Color(hex: swatch.rawValue))
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        Circle()
                                            .stroke(Theme.paper, lineWidth: 2)
                                    }
                                    .overlay {
                                        Circle()
                                            .stroke(Theme.ink, lineWidth: color == swatch ? 1.5 : 0)
                                            .padding(-4)
                                    }
                                    .frame(width: 40, height: 40)
                            }
                            .accessibilityLabel(swatch.name)
                            .accessibilityAddTraits(color == swatch ? .isSelected : AccessibilityTraits())
                        }
                    }
                }
                .frame(height: 40)
            }

            HStack(spacing: 18) {
                ForEach(BrushSize.allCases) { option in
                    Button {
                        size = option
                    } label: {
                        Circle()
                            .fill(size == option ? Theme.ink : Theme.secondary.opacity(0.45))
                            .frame(width: CGFloat(8 + option.rawValue * 280), height: CGFloat(8 + option.rawValue * 280))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(option.name)
                }
            }

            if let notice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Theme.dock)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func barButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 44, height: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func commit() {
        feedback += 1
        model.applyLocal(drawing.document)
    }

    private func finish() {
        commit()
        Task { await model.flush() }
        dismiss()
    }
}

private struct TextComposer: View {
    var title: String
    var initial: String
    var canDelete: Bool
    var onSave: (String) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(title: String, initial: String, canDelete: Bool, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.title = title
        self.initial = initial
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Write something", text: $text, axis: .vertical)
                    .font(.system(.title2, design: .serif))
                    .lineLimit(2...5)
                    .focused($focused)
                    .padding(16)
                    .background(Theme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.desk)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(canDelete ? "Save" : "Add") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if canDelete {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Remove", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
