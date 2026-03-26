import SwiftUI

struct MenusView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = MenusViewModel()

    @State private var showAddCategorySheet = false
    @State private var selectedCategoryForNewItem: MenuCategory?

    var body: some View {
        NavigationStack {
            Group {
                if let profileID = auth.profile?.id {
                    content(profileID: profileID)
                } else {
                    ContentUnavailableView(
                        "Brak profilu",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Nie udało się odczytać użytkownika")
                    )
                }
            }
            .navigationTitle("Menu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCategorySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet { name, description in
                    Task {
                        await viewModel.addCategory(name: name, description: description)
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private func content(profileID: UUID) -> some View {
        List {
            if viewModel.isLoading {
                ProgressView("Ładowanie...")
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            if viewModel.categories.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "Brak kategorii",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Dodaj pierwszą kategorię menu")
                )
            } else {
                ForEach(viewModel.categories) { category in
                    Section {
                        let categoryItems = viewModel.items(for: category.id)

                        if let desc = category.description, !desc.isEmpty {
                            Text(desc)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if categoryItems.isEmpty {
                            Text("Brak pozycji")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(categoryItems) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(.headline)

                                            if let description = item.description, !description.isEmpty {
                                                Text(description)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let weight = item.weight, !weight.isEmpty {
                                                Text(weight)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            HStack(spacing: 8) {
                                                if item.isRecommended {
                                                    Label("Polecane", systemImage: "star.fill")
                                                        .font(.caption2)
                                                }

                                                if item.isSpicy {
                                                    Label("Pikantne", systemImage: "flame.fill")
                                                        .font(.caption2)
                                                }

                                                if item.isVegetarian {
                                                    Label("Wege", systemImage: "leaf.fill")
                                                        .font(.caption2)
                                                }
                                            }
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("\(Int(item.price)) zł")
                                                .font(.headline)

                                            if let oldPrice = item.oldPrice {
                                                Text("\(Int(oldPrice)) zł")
                                                    .font(.caption)
                                                    .strikethrough()
                                                    .foregroundStyle(.secondary)
                                            }

                                            if !item.isAvailable {
                                                Text("Niedostępne")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteItem(item)
                                        }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        Button {
                            selectedCategoryForNewItem = category
                        } label: {
                            Label("Dodaj pozycję", systemImage: "plus.circle.fill")
                        }
                    } header: {
                        Text(category.name)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteCategory(category)
                            }
                        } label: {
                            Label("Usuń", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            await viewModel.load(profileID: profileID)
        }
        .refreshable {
            await viewModel.load(profileID: profileID)
        }
        .sheet(item: $selectedCategoryForNewItem) { category in
            AddMenuItemSheet(category: category) { draft in
                Task {
                    await viewModel.addItem(
                        categoryID: category.id,
                        name: draft.name,
                        description: draft.description,
                        price: draft.price,
                        oldPrice: draft.oldPrice,
                        weight: draft.weight,
                        allergens: draft.allergens,
                        tags: draft.tags,
                        isRecommended: draft.isRecommended,
                        isSpicy: draft.isSpicy,
                        isVegetarian: draft.isVegetarian
                    )
                }
            }
            .presentationDetents([.large])
        }
    }
}
