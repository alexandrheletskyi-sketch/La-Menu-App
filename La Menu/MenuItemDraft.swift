import SwiftUI

struct MenuItemDraft {
    var name: String
    var description: String
    var price: Double
    var oldPrice: Double?
    var weight: String
    var allergens: String
    var tags: String
    var isRecommended: Bool
    var isSpicy: Bool
    var isVegetarian: Bool
}

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategoria") {
                    Text(category.name)
                }

                Section("Podstawowe dane") {
                    TextField("Nazwa", text: $name)
                    TextField("Opis", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                    TextField("Cena", text: $priceText)
                        .keyboardType(.decimalPad)
                    TextField("Stara cena", text: $oldPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Waga", text: $weight)
                }

                Section("Dodatkowe informacje") {
                    TextField("Alergeny", text: $allergens)
                    TextField("Tagi", text: $tags)
                }

                Section("Cechy") {
                    Toggle("Polecane", isOn: $isRecommended)
                    Toggle("Pikantne", isOn: $isSpicy)
                    Toggle("Wegetariańskie", isOn: $isVegetarian)
                }
            }
            .navigationTitle("Nowa pozycja")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapisz") {
                        let normalizedPrice = priceText.replacingOccurrences(of: ",", with: ".")
                        let normalizedOldPrice = oldPriceText.replacingOccurrences(of: ",", with: ".")

                        let draft = MenuItemDraft(
                            name: name,
                            description: description,
                            price: Double(normalizedPrice) ?? 0,
                            oldPrice: oldPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Double(normalizedOldPrice),
                            weight: weight,
                            allergens: allergens,
                            tags: tags,
                            isRecommended: isRecommended,
                            isSpicy: isSpicy,
                            isVegetarian: isVegetarian
                        )

                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
