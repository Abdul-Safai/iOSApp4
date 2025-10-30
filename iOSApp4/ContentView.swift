import SwiftUI
import PhotosUI

struct ContentView: View {
    let uid: String
    @StateObject private var store: ItemStore

    init(uid: String) {
        self.uid = uid
        _store = StateObject(wrappedValue: ItemStore(uid: uid))
    }

    @State private var newTitle = ""
    @State private var editingItem: Item?
    @State private var editedTitle = ""
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Add new item
                HStack {
                    TextField("New item title…", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        store.add(title: t); newTitle = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                // Upload progress
                if store.isUploading {
                    VStack(spacing: 6) {
                        ProgressView(value: store.uploadProgress)
                        Text("Uploading… \(Int(store.uploadProgress * 100))%")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let err = store.errorMessage, !err.isEmpty {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }

                // Items list
                List {
                    ForEach(store.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.title).font(.headline)
                                Spacer()
                                Text(Date(timeIntervalSince1970: item.createdAt), style: .time)
                                    .font(.caption).foregroundStyle(.secondary)
                            }

                            if let url = item.imageURL.flatMap(URL.init(string:)) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack { Rectangle().fill(.gray.opacity(0.15)); ProgressView() }
                                            .frame(height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .success(let img):
                                        img.resizable().scaledToFill().frame(height: 140).clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .failure:
                                        Text("Image failed to load").foregroundStyle(.secondary)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }

                            HStack(spacing: 8) {
                                Button { editingItem = item; editedTitle = item.title } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Label("Upload Image", systemImage: "photo.on.rectangle.angled")
                                }
                                .onChange(of: photoItem) { _, newVal in
                                    guard let newVal else { return }
                                    Task {
                                        if let data = try? await newVal.loadTransferable(type: Data.self),
                                           let img = UIImage(data: data) {
                                            store.uploadImage(img, for: item)
                                        }
                                        await MainActor.run { photoItem = nil }
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .swipeActions {
                            Button(role: .destructive) { store.delete(item: item) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("iOSApp4 (Firebase)")
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item, editedTitle: $editedTitle) { newTitle in
                store.update(item: item, newTitle: newTitle)
            }
        }
    }
}

struct EditItemSheet: View {
    let item: Item
    @Binding var editedTitle: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form { TextField("Title", text: $editedTitle) }
                .navigationTitle("Edit Item")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let t = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            onSave(t); dismiss()
                        }
                    }
                }
        }
    }
}
