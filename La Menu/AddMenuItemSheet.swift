import SwiftUI
import PhotosUI
import UIKit

struct AddMenuItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: MenuCategory
    let onSave: (MenuItemDraft) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var oldPriceText = ""
    @State private var weight = ""
    @State private var allergens = ""
    @State private var tags = ""
    @State private var isRecommended = false
    @State private var isSpicy = false
    @State private var isVegetarian = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageData: Data?

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                    TextField("Stara cena", text: $oldPriceText)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                        .keyboardType(.decimalPad)

                    TextField("Waga", text: $weight)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                }

                Section("Dodatkowe informacje") {
                    TextField("Alergeny", text: $allergens)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))

                    TextField("Tagi", text: $tags)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                }

                Section("Cechy") {
                    Toggle("Polecane", isOn: $isRecommended)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))

                    Toggle("Pikantne", isOn: $isSpicy)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))

                    Toggle("Wegetariańskie", isOn: $isVegetarian)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                }
            }
            .font(.custom("WixMadeforDisplay-Regular", size: 16))
            .navigationTitle("Nowa pozycja")
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
                        let normalizedPrice = priceText.replacingOccurrences(of: ",", with: ".")
                        let normalizedOldPrice = oldPriceText.replacingOccurrences(of: ",", with: ".")

                        let draft = MenuItemDraft(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            price: Double(normalizedPrice) ?? 0,
                            oldPrice: oldPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? nil
                                : Double(normalizedOldPrice),
                            weight: weight.trimmingCharacters(in: .whitespacesAndNewlines),
                            allergens: allergens.trimmingCharacters(in: .whitespacesAndNewlines),
                            tags: tags.trimmingCharacters(in: .whitespacesAndNewlines),
                            isRecommended: isRecommended,
                            isSpicy: isSpicy,
                            isVegetarian: isVegetarian,
                            imageData: imageData
                        )

                        onSave(draft)
                        dismiss()
                    }
                    .font(.custom("WixMadeforDisplay-Bold", size: 16))
                    .disabled(isSaveDisabled)
                }
            }
            .task(id: selectedPhotoItem) {
                guard let selectedPhotoItem else { return }

                do {
                    if let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        imageData = uiImage.jpegData(compressionQuality: 0.82)
                    }
                } catch {
                    print("Photo loading error:", error)
                }
            }
        }
    }
}
