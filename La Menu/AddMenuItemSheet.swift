import SwiftUI
import PhotosUI
import UIKit

struct AddMenuItemSheet: View {
    enum Mode {
        case add
        case edit(MenuItem)
    }

    @Environment(\.dismiss) private var dismiss

    let profile: Profile
    let currentItemsCount: Int
    let category: MenuCategory
    let mode: Mode
    let onSave: (MenuItemDraft) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var weight = ""
    @State private var allergensText = ""

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageData: Data?

    @State private var showPlansView = false

    private var isEditing: Bool {
        switch mode {
        case .add:
            return false
        case .edit:
            return true
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentPlan: SubscriptionPlan {
        profile.subscriptionPlan
    }

    private var wouldExceedMenuLimit: Bool {
        guard !isEditing else { return false }

        guard let limit = currentPlan.menuItemLimit else {
            return false
        }

        return currentItemsCount >= limit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategoria") {
                    Text(category.name)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                }

                Section("Zdjęcie") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))

                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)

                                    Text("Brak zdjęcia")
                                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 160)
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(
                                selectedImage == nil ? "Wybierz zdjęcie" : "Zmień zdjęcie",
                                systemImage: "photo.on.rectangle"
                            )
                            .font(.custom("WixMadeforDisplay-Medium", size: 16))
                        }

                        if selectedImage != nil {
                            Button(role: .destructive) {
                                selectedPhotoItem = nil
                                selectedImage = nil
                                imageData = nil
                            } label: {
                                Label("Usuń zdjęcie", systemImage: "trash")
                                    .font(.custom("WixMadeforDisplay-Medium", size: 16))
                            }
                        }

                        if let imageData {
                            Text("Rozmiar zdjęcia: \(formattedFileSize(imageData.count))")
                                .font(.custom("WixMadeforDisplay-Regular", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Podstawowe dane") {
                    TextField("Nazwa", text: $name)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))

                    TextField("Opis", text: $description, axis: .vertical)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                        .lineLimit(3...5)

                    TextField("Cena", text: $priceText)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                        .keyboardType(.decimalPad)

                    TextField("Waga", text: $weight)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))

                    TextField("Alergeny", text: $allergensText, axis: .vertical)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                        .lineLimit(2...4)

                    Text("Wpisz alergeny po przecinku, np. gluten, mleko, orzechy")
                        .font(.custom("WixMadeforDisplay-Regular", size: 13))
                        .foregroundStyle(.secondary)
                }

                if !isEditing, let limit = currentPlan.menuItemLimit {
                    Section("Plan") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Aktualny plan: \(currentPlan.title)")
                                .font(.custom("WixMadeforDisplay-SemiBold", size: 15))

                            Text("Pozycje w menu: \(currentItemsCount)/\(limit)")
                                .font(.custom("WixMadeforDisplay-Regular", size: 14))
                                .foregroundStyle(.secondary)

                            if wouldExceedMenuLimit {
                                Text("Osiągnięto limit pozycji dla planu \(currentPlan.title). Aby dodać kolejną pozycję, wybierz wyższy plan.")
                                    .font(.custom("WixMadeforDisplay-Regular", size: 14))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .font(.custom("WixMadeforDisplay-Regular", size: 16))
            .navigationTitle(isEditing ? "Edytuj pozycję" : "Nowa pozycja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj") {
                        dismiss()
                    }
                    .font(.custom("WixMadeforDisplay-Medium", size: 16))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapisz") {
                        handleSaveTapped()
                    }
                    .font(.custom("WixMadeforDisplay-Bold", size: 16))
                    .disabled(isSaveDisabled)
                }
            }
            .task {
                populateIfNeeded()
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
            .sheet(isPresented: $showPlansView) {
                NavigationStack {
                    PlansView(
                        currentPlan: currentPlan,
                        currentSmsCredits: profile.currentSmsCredits ?? 0
                    )
                }
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                return
            }

            let optimizedImage = uiImage.optimizedForMenuImage(maxDimension: 1000)
            let optimizedData = optimizedImage.jpegData(compressionQuality: 0.70)

            await MainActor.run {
                selectedImage = optimizedImage
                imageData = optimizedData
            }

            print("Original image size:", formattedFileSize(data.count))
            print("Optimized image size:", formattedFileSize(optimizedData?.count ?? 0))
        } catch {
            print("Photo loading error:", error)
        }
    }

    private func handleSaveTapped() {
        if wouldExceedMenuLimit {
            showPlansView = true
            return
        }

        let normalizedPrice = priceText.replacingOccurrences(of: ",", with: ".")

        let draft = MenuItemDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            price: Double(normalizedPrice) ?? 0,
            weight: weight.trimmingCharacters(in: .whitespacesAndNewlines),
            allergensText: allergensText.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: imageData
        )

        onSave(draft)
        dismiss()
    }

    private func populateIfNeeded() {
        switch mode {
        case .add:
            return

        case .edit(let item):
            name = item.name
            description = item.description ?? ""
            priceText = item.price == floor(item.price)
                ? String(Int(item.price))
                : String(format: "%.2f", item.price)
            weight = item.weight ?? ""
            allergensText = item.allergens?.joined(separator: ", ") ?? ""

            if let imageURL = item.imageURL,
               let url = URL(string: imageURL) {
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)

                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                selectedImage = uiImage
                                imageData = nil
                            }
                        }
                    } catch {
                        print("Image loading error:", error)
                    }
                }
            }
        }
    }

    private func formattedFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private extension UIImage {
    func optimizedForMenuImage(maxDimension: CGFloat) -> UIImage {
        let normalizedImage = fixedOrientation()

        let originalWidth = normalizedImage.size.width
        let originalHeight = normalizedImage.size.height
        let largestSide = max(originalWidth, originalHeight)

        guard largestSide > maxDimension else {
            return normalizedImage
        }

        let scale = maxDimension / largestSide

        let newSize = CGSize(
            width: originalWidth * scale,
            height: originalHeight * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { _ in
            normalizedImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
