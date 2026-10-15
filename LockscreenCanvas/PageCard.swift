import SwiftUI

struct PageCard: View {
    var document: CanvasDocument

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CanvasRenderView(document: document)
                    .padding(18)
                    .background(Theme.paper)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
    }
}
