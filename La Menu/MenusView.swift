import SwiftUI

struct MenusView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = MenusViewModel()

    @State private var showAddCategorySheet = false
    @State private var selectedCategoryForNewItem: MenuCategory?
    @State private var editingItem: MenuItem?
    @State private var showPlansView = false
    @State private var categoryPendingDeletion: MenuCategory?

    private let pageBackground = Color.white
    private let softFill = Color.black.opacity(0.04)
    private let softBorder = Color.black.opacity(0.07)
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)

    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let accentOrangeSoft = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0).opacity(0.14)
    private let accentOrangeText = Color(red: 0.86, green: 0.26, blue: 0.04)

    private let accentGreen = Color(red: 99 / 255, green: 225 / 255, blue: 141 / 255)
    private let accentGreenText = Color(red: 0.22, green: 0.58, blue: 0.34)

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                Group {
                    if let profile = auth.profile {
                        content(profile: profile)
                    } else {
                        ContentUnavailableView(
                            "Brak profilu",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("Nie udało się odczytać użytkownika")
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddCategorySheet) {
                SimpleAddCategorySheet { name in
                    Task {
                        await viewModel.addCategory(name: name, description: "")
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $selectedCategoryForNewItem) { category in
                if let profile = auth.profile {
                    AddMenuItemSheet(
                        profile: profile,
                        currentItemsCount: totalItemsCount,
                        category: category,
                        mode: .add
                    ) { draft in
                        Task {
                            await viewModel.addItem(
                                categoryID: category.id,
                                name: draft.name,
                                description: draft.description,
                                price: draft.price,
                                weight: draft.weight,
                                allergensText: draft.allergensText,
                                imageData: draft.imageData
                            )
                        }
                    }
                    .presentationDetents([.large])
                } else {
                    ContentUnavailableView(
                        "Brak profilu",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Nie udało się odczytać planu użytkownika")
                    )
                }
            }
            .sheet(item: $editingItem) { item in
                if let profile = auth.profile,
                   let category = viewModel.categories.first(where: { $0.id == item.categoryID }) {
                    AddMenuItemSheet(
                        profile: profile,
                        currentItemsCount: totalItemsCount,
                        category: category,
                        mode: .edit(item)
                    ) { draft in
                        Task {
                            await viewModel.updateItem(item, with: draft)
                        }
                    }
                    .presentationDetents([.large])
                } else {
                    ContentUnavailableView(
                        "Brak danych",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Nie udało się otworzyć edycji pozycji")
                    )
                }
            }
            .sheet(isPresented: $showPlansView) {
                if let profile = auth.profile {
                    NavigationStack {
                        PlansView(
                            currentPlan: profile.subscriptionPlan,
                            currentSmsCredits: profile.currentSmsCredits ?? 0
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "Brak profilu",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Nie udało się odczytać planu użytkownika")
                    )
                }
            }
            .alert(
                "Usunąć kategorię?",
                isPresented: Binding(
                    get: { categoryPendingDeletion != nil },
                    set: { newValue in
                        if !newValue {
                            categoryPendingDeletion = nil
                        }
                    }
                )
            ) {
                Button("Anuluj", role: .cancel) {
                    categoryPendingDeletion = nil
                }

                Button("Usuń", role: .destructive) {
                    if let category = categoryPendingDeletion {
                        Task {
                            await viewModel.deleteCategory(category)
                            categoryPendingDeletion = nil
                        }
                    }
                }
            } message: {
                Text("Ta akcja usunie kategorię oraz wszystkie pozycje z tej kategorii")
            }
        }
    }

    private func content(profile: Profile) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection(profile: profile)

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    errorCard(errorMessage)
                }

                if viewModel.isLoading && viewModel.categories.isEmpty {
                    loadingCard
                } else if viewModel.categories.isEmpty {
                    emptyStateCard
                } else {
                    categoriesSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 120)
        }
        .background(Color.white)
        .scrollContentBackground(.hidden)
        .task(id: profile.id) {
            await viewModel.load(profileID: profile.id)
        }
        .refreshable {
            await viewModel.load(profileID: profile.id)
        }
    }

    private func headerSection(profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Menu")
                .font(.custom("WixMadeforDisplay-Bold", size: 44))
                .foregroundStyle(.black)

            Text("Zarządzaj kategoriami, dodawaj pozycje i utrzymuj ofertę w aktualnym porządku")
                .font(.custom("WixMadeforDisplay-Regular", size: 17))
                .foregroundStyle(mutedText)
                .lineSpacing(2)
                .frame(maxWidth: 340, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    summaryPill(
                        title: "Kategorie",
                        value: "\(viewModel.categories.count)",
                        foreground: accentOrangeText,
                        background: accentOrangeSoft
                    )

                    summaryPill(
                        title: "Pozycje",
                        value: "\(totalItemsCount)",
                        foreground: accentGreenText,
                        background: accentGreen.opacity(0.18)
                    )

                    summaryPill(
                        title: "Plan",
                        value: profile.subscriptionPlan.title,
                        foreground: .black.opacity(0.62),
                        background: Color.black.opacity(0.025)
                    )

                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)

                            Text("Ładowanie")
                                .font(.custom("WixMadeforDisplay-Medium", size: 13))
                        }
                        .foregroundStyle(mutedText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.035))
                        .clipShape(Capsule())
                    }
                }
            }

            Button {
                showAddCategorySheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))

                    Text("Dodaj kategorię")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(accentOrange)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: accentOrange.opacity(0.22), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryPill(title: String, value: String, foreground: Color, background: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.custom("WixMadeforDisplay-Medium", size: 13))

            Text(value)
                .font(.custom("WixMadeforDisplay-SemiBold", size: 13))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(Capsule())
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.10))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Wystąpił problem")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                    .foregroundStyle(.black)

                Text(message)
                    .font(.custom("WixMadeforDisplay-Regular", size: 14))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .uberCardStyle()
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text("Ładowanie menu...")
                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .uberCardStyle()
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentOrangeSoft)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentOrangeText)
                )

            Text("Brak kategorii")
                .font(.custom("WixMadeforDisplay-SemiBold", size: 22))
                .foregroundStyle(.black)

            Text("Dodaj pierwszą kategorię, aby zacząć budować swoje menu")
                .font(.custom("WixMadeforDisplay-Regular", size: 15))
                .foregroundStyle(mutedText)

            Button {
                showAddCategorySheet = true
            } label: {
                Text("Dodaj kategorię")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accentOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .uberCardStyle()
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(viewModel.categories) { category in
                categoryCard(category)
            }
        }
    }

    private func categoryCard(_ category: MenuCategory) -> some View {
        let categoryItems = viewModel.items(for: category.id)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(.custom("WixMadeforDisplay-Bold", size: 28))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = category.description,
                       !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(description)
                            .font(.custom("WixMadeforDisplay-Regular", size: 15))
                            .foregroundStyle(mutedText)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 12)

                Text("\(categoryItems.count)")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                    .foregroundStyle(accentGreenText)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(accentGreen.opacity(0.18))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                Button {
                    handleAddItemTapped(for: category)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))

                        Text("Dodaj pozycję")
                            .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.black.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.045), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    categoryPendingDeletion = category
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))

                        Text("Usuń")
                            .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                    }
                    .foregroundStyle(.red)
                    .frame(width: 104)
                    .frame(height: 48)
                    .background(Color.red.opacity(0.075))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(height: 1)

            if categoryItems.isEmpty {
                emptyCategoryContent
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryItems) { item in
                        MenuItemCard(
                            item: item,
                            softFill: softFill,
                            mutedText: mutedText,
                            secondaryText: secondaryText,
                            accentGreen: accentGreen,
                            accentGreenText: accentGreenText,
                            onEdit: {
                                editingItem = item
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteItem(item)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(20)
        .uberCardStyle()
    }

    private var emptyCategoryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Brak pozycji w tej kategorii")
                .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                .foregroundStyle(.black)

            Text("Dodaj pierwszą pozycję, aby kategoria zaczęła wyglądać jak gotowe menu")
                .font(.custom("WixMadeforDisplay-Regular", size: 14))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var totalItemsCount: Int {
        viewModel.items.count
    }

    private func canAddMoreItems(profile: Profile) -> Bool {
        guard let limit = profile.subscriptionPlan.menuItemLimit else {
            return true
        }

        return totalItemsCount < limit
    }

    private func handleAddItemTapped(for category: MenuCategory) {
        guard let profile = auth.profile else { return }

        if canAddMoreItems(profile: profile) {
            selectedCategoryForNewItem = category
        } else {
            showPlansView = true
        }
    }
}

private struct SimpleAddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    let onSave: (String) -> Void

    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let mutedText = Color.black.opacity(0.58)

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Nowa kategoria")
                    .font(.custom("WixMadeforDisplay-Bold", size: 30))
                    .foregroundStyle(.black)

                Text("Wpisz nazwę kategorii, np. Pizza, Sushi albo Napoje")
                    .font(.custom("WixMadeforDisplay-Regular", size: 15))
                    .foregroundStyle(mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Nazwa kategorii")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 14))
                    .foregroundStyle(.black)

                TextField("Np. Pizza", text: $name)
                    .font(.custom("WixMadeforDisplay-Regular", size: 17))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color.black.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Spacer()

            Button {
                let finalName = trimmedName

                guard !finalName.isEmpty else {
                    return
                }

                onSave(finalName)
                dismiss()
            } label: {
                Text("Dodaj kategorię")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(trimmedName.isEmpty ? Color.black.opacity(0.18) : accentOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(trimmedName.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.white)
    }
}

private struct MenuItemCard: View {
    let item: MenuItem
    let softFill: Color
    let mutedText: Color
    let secondaryText: Color
    let accentGreen: Color
    let accentGreenText: Color
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var descriptionParts: [String] {
        guard let description = item.description,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return description
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var shouldShowAsChips: Bool {
        descriptionParts.count >= 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                itemImage
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.name)
                            .font(.custom("WixMadeforDisplay-Bold", size: 20))
                            .foregroundStyle(.black)
                            .lineLimit(3)
                            .minimumScaleFactor(0.86)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(2)

                        pricePill
                            .fixedSize()
                            .layoutPriority(1)
                    }

                    if shouldShowAsChips {
                        ingredientsChips
                    } else if let description = item.description,
                              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(description)
                            .font(.custom("WixMadeforDisplay-Regular", size: 14))
                            .foregroundStyle(mutedText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        if let weight = item.weight,
                           !weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            smallInfoPill(weight)
                        }

                        if !item.isAvailable {
                            smallStatusPill("Niedostępne")
                        }

                        Spacer(minLength: 8)

                        menuButton
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let allergens = item.allergens, !allergens.isEmpty {
                Text("Alergeny: \(allergens.joined(separator: ", "))")
                    .font(.custom("WixMadeforDisplay-Medium", size: 12))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.055), lineWidth: 1)
        )
    }

    private var pricePill: some View {
        Text("\(Int(item.price)) zł")
            .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
            .foregroundStyle(accentGreenText)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(accentGreen.opacity(0.18))
            .clipShape(Capsule())
    }

    private var ingredientsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(descriptionParts.prefix(8), id: \.self) { part in
                    Text(part)
                        .font(.custom("WixMadeforDisplay-Medium", size: 12))
                        .foregroundStyle(mutedText)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.035))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallInfoPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("WixMadeforDisplay-Medium", size: 12))
            .foregroundStyle(mutedText)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.035))
            .clipShape(Capsule())
    }

    private func smallStatusPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("WixMadeforDisplay-Medium", size: 12))
            .foregroundStyle(.red)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.08))
            .clipShape(Capsule())
    }

    private var menuButton: some View {
        SwiftUI.Menu {
            Button {
                onEdit()
            } label: {
                Label("Edytuj pozycję", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Usuń pozycję", systemImage: "trash")
            }
        } label: {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(softFill)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var itemImage: some View {
        let imageSize: CGFloat = 74
        let cornerRadius: CGFloat = 18

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.04))

            if let imageURL = item.imageURL,
               !imageURL.isEmpty,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageSize, height: imageSize)
                            .clipped()

                    case .failure:
                        Image(systemName: "fork.knife")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.65))

                    @unknown default:
                        Image(systemName: "fork.knife")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.65))
                    }
                }
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.65))
            }
        }
        .frame(width: imageSize, height: imageSize)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.04))

            Image(systemName: "fork.knife")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.black.opacity(0.65))
        }
    }
}

private struct UberCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.025), radius: 10, x: 0, y: 3)
    }
}

private extension View {
    func uberCardStyle() -> some View {
        modifier(UberCardModifier())
    }
}

#Preview {
    MenusView()
}
