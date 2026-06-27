import SwiftUI
import SwiftData

/// The home of Le Castelet: a velvet-curtained galerie of saved rooms. Each card is a little
/// maquette you can tap to hold as a dollhouse, plus a prominent "numériser" button to capture
/// a new one (or, where scanning isn't supported, to add the bundled sample).
struct GalerieView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Castelet.createdAt, order: .reverse) private var rooms: [Castelet]

    @State private var presentingScan = false
    @State private var roomToOpen: Castelet?
    @State private var renaming: Castelet?
    @State private var renameText = ""

    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.stageC.ignoresSafeArea()
                content
            }
            .navigationTitle("Le Castelet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentingScan = true
                    } label: {
                        Image(systemName: "viewfinder")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Numériser une pièce")
                }
            }
            .fullScreenCover(isPresented: $presentingScan) {
                ScanFlowView()
            }
            .fullScreenCover(item: $roomToOpen) { room in
                DollhouseView(room: room)
            }
            .alert("Renommer", isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("Nom de la pièce", text: $renameText)
                Button("Annuler", role: .cancel) { renaming = nil }
                Button("Enregistrer") {
                    if let r = renaming {
                        r.name = renameText
                        try? context.save()
                    }
                    renaming = nil
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if rooms.isEmpty {
            EmptyGalerieView { presentingScan = true }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(rooms) { room in
                        RoomCard(room: room)
                            .onTapGesture { roomToOpen = room }
                            .contextMenu {
                                Button {
                                    renameText = room.name
                                    renaming = room
                                } label: { Label("Renommer", systemImage: "pencil") }

                                if !room.isSample {
                                    Button(role: .destructive) {
                                        delete(room)
                                    } label: { Label("Supprimer", systemImage: "trash") }
                                }
                            }
                    }
                }
                .padding(16)
            }
        }
    }

    private func delete(_ room: Castelet) {
        CasteletStorage.deleteModel(filename: room.modelFilename)
        context.delete(room)
        try? context.save()
    }
}

/// A single maquette card — thumbnail (or a drawn placeholder), name and tiny stats.
private struct RoomCard: View {
    let room: Castelet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Theme.velvetC, Theme.velvetDeepC],
                    startPoint: .top, endPoint: .bottom
                )
                if let data = room.thumbnailData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    MaquettePlaceholder()
                }
                // Footlight glow at the base of the card, theatre-style.
                LinearGradient(
                    colors: [.clear, Theme.footlightC.opacity(0.32)],
                    startPoint: .center, endPoint: .bottom
                )
            }
            .frame(height: 132)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(room.displayName)
                    .font(.playbill(16, weight: .semibold))
                    .foregroundStyle(Theme.inkC)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if room.isSample {
                        Label("Exemple", systemImage: "sparkles")
                            .labelStyle(.titleAndIcon)
                    } else {
                        Label(String(format: "%.0f m²", room.floorAreaSquareMetres), systemImage: "square.dashed")
                    }
                    Label("\(room.objectCount)", systemImage: "cube")
                }
                .font(.caption2)
                .foregroundStyle(Theme.secondaryC)
                .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.boardC)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.brassC.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

/// A drawn little house silhouette, used when a room has no rendered thumbnail yet.
private struct MaquettePlaceholder: View {
    var body: some View {
        Image(systemName: "house.lodge.fill")
            .font(.system(size: 46, weight: .regular))
            .foregroundStyle(Theme.brassC.opacity(0.85))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

/// Shown when the galerie is empty (extremely rare — the sample seeds on first launch).
private struct EmptyGalerieView: View {
    var onScan: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.brassC)
            Text("Votre castelet est vide")
                .font(.playbill(22))
                .foregroundStyle(Theme.inkC)
            Text("Numérisez une pièce pour la tenir\ndans la paume de votre main.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryC)
            Button(action: onScan) {
                Label("Numériser une pièce", systemImage: "viewfinder")
                    .font(.headline)
                    .padding(.horizontal, 22).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.velvetC)
            .padding(.top, 6)
        }
        .padding(40)
    }
}
