import SwiftUI
import PhotosUI   // for PHPicker

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var store = ItemStore()

    @State private var newTitle: String = ""
    @State private var editingItem: AppItem? = nil

    // image picking
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage? = nil
    @State private var targetItemForImage: AppItem? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {

                // Add row
                AddRow(newTitle: $newTitle) {
                    guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.add(title: newTitle.trimmingCharacters(in: .whitespaces))
                    newTitle = ""
                }

                // Upload progress / notice
                if store.isUploading {
                    ProgressView(value: store.uploadProgress)
                        .padding(.horizontal)
                }
                if let notice = store.notice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }

                // Items list
                List {
                    ForEach(store.items) { item in
                        ItemRow(
                            item: item,
                            editAction: { editingItem = item },
                            pickImageAction: {
                                targetItemForImage = item
                                showImagePicker = true
                            },
                            deleteAction: { store.delete(item) }
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("iOSApp4 (Firebase)")
        }
        // Image picker sheet
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $pickedImage)
                .onDisappear {
                    guard let img = pickedImage, let target = targetItemForImage else {
                        pickedImage = nil
                        return
                    }
                    store.attachImage(img, to: target)
                    pickedImage = nil
                    targetItemForImage = nil
                }
        }
        // Edit title sheet (simple & fast to type-check)
        .sheet(item: $editingItem) { it in
            EditTitleSheet(
                currentTitle: it.title,
                onSave: { newTitle in
                    store.updateTitle(it, to: newTitle)
                }
            )
        }
    }
}

// MARK: - AddRow
private struct AddRow: View {
    @Binding var newTitle: String
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("New item title…", text: $newTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Add", action: onAdd)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - ItemRow
private struct ItemRow: View {
    let item: AppItem
    let editAction: () -> Void
    let pickImageAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Thumbnail(urlString: item.imageURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.createdAtFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                editAction()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button {
                pickImageAction()
            } label: {
                Image(systemName: "photo")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                deleteAction()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Thumbnail
private struct Thumbnail: View {
    let urlString: String?

    var body: some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        Color.gray.opacity(0.15)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .font(.caption)
            )
    }
}

// MARK: - EditTitleSheet
private struct EditTitleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String
    var onSave: (String) -> Void

    init(currentTitle: String, onSave: @escaping (String) -> Void) {
        _titleText = State(initialValue: currentTitle)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Title", text: $titleText)
                }
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { dismiss(); return }
                        onSave(trimmed)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - UIKit PHPicker wrapper (ImagePicker)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.selectedImage = uiImage
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
