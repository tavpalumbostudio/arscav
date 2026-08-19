import SwiftUI

struct CollectionGridView: View {
    @ObservedObject var engine: HuntEngine
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let round = engine.currentRound
                    VStack(alignment: .leading, spacing: 8) {
                        Text(round.title.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(engine.sessionTargetIDs.isEmpty ? round.targets : engine.sessionTargetIDs, id: \.self) { id in
                                tile(object: round.object(id: id), found: engine.foundIDs.contains(id))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(engine.currentRound.isPredatorHunt ? "Prey spotted" : "Found items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(object: HuntObject?, found: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemFill))
            if found, let object, let image = engine.faceImages[object.id] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(uiImage: CardTextureFactory.silhouette())
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .opacity(0.7)
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
