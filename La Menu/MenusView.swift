import SwiftUI

struct MenusView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = MenusViewModel()

    @State private var showAddCategorySheet = false
    @State private var selectedCategoryForNewItem: MenuCategory?

    private let pageBackground = Color(red: 0.965, green: 0.965, blue: 0.965)
    private let cardBackground = Color.white
    private let softFill = Color.black.opacity(0.04)
    private let softBorder = Color.black.opacity(0.08)
    private let mutedText = Color.black.opacity(0.58)
    private let accentOrange = Color(red: 1.000, green: 0.557, blue: 0.176)
    private let accentGreen = Color(red: 99/255, green: 225/255, blue: 141/255)
    private let accentGreenText = Color(red: 0.22, green: 0.58, blue: 0.34)
    private let accentBlue = Color(red: 0.86, green: 0.93, blue: 1.00)
    private let accentBlueText = Color(red: 0.12, green: 0.52, blue: 0.96)

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

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
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet { name, description in
                    Task {
                        await viewModel.addCategory(name: name, description: description)
                    }
                }
                .presentationDetents([.medium])
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
                            isVegetarian: draft.isVegetarian,
                            imageData: draft.imageData
                        )
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private func content(profileID: UUID) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

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
        .task(id: profileID) {
            await viewModel.load(profileID: profileID)
        }
        .refreshable {
            await viewModel.load(profileID: profileID)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Menu")
                .font(.custom("WixMadeforDisplay-Bold", size: 44))
                .foregroundStyle(.black)

            Text("Zarządzaj kategoriami, dodawaj pozycje i utrzymuj ofertę w aktualnym porządku")
                .font(.custom("WixMadeforDisplay-Regular", size: 17))
                .foregroundStyle(mutedText)
                .lineSpacing(2)
                .frame(maxWidth: 330, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                summaryPill(
                    title: "Kategorie",
                    value: viewModel.categories.count,
                    foreground: accentBlueText,
                    background: accentBlue
                )

                summaryPill(
                    title: "Pozycje",
                    value: totalItemsCount,
                    foreground: accentGreenText,
                    background: accentGreen.opacity(0.18)
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
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
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
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryPill(title: String, value: Int, foreground: Color, background: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.custom("WixMadeforDisplay-Medium", size: 13))

            Text("\(value)")
                .font(.custom("WixMadeforDisplay-SemiBold", size: 13))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
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
                .fill(softFill)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
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
                    .background(Color.black)
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

                    if let description = category.description, !description.isEmpty {
                        Text(description)
                            .font(.custom("WixMadeforDisplay-Regular", size: 15))
                            .foregroundStyle(mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    Text("\(categoryItems.count)")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                        .foregroundStyle(accentGreenText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(accentGreen.opacity(0.18))
                        .clipShape(Capsule())

                    SwiftUI.Menu {
                        Button {
                            selectedCategoryForNewItem = category
                        } label: {
                            Label("Dodaj pozycję", systemImage: "plus")
                        }

                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteCategory(category)
                            }
                        } label: {
                            Label("Usuń kategorię", systemImage: "trash")
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(softFill)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(height: 1)

            if categoryItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Brak pozycji w tej kategorii")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                        .foregroundStyle(.black)

                    Text("Dodaj pierwszą pozycję, aby kategoria zaczęła wyglądać jak gotowe menu")
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(mutedText)

                    Button {
                        selectedCategoryForNewItem = category
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))

                            Text("Dodaj pozycję")
                                .font(.custom("WixMadeforDisplay-SemiBold", size: 16))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryItems) { item in
                        MenuItemCard(
                            item: item,
                            softFill: softFill,
                            mutedText: mutedText,
                            accentGreen: accentGreen,
                            accentGreenText: accentGreenText,
                            accentOrange: accentOrange
                        ) {
                            Task {
                                await viewModel.deleteItem(item)
                            }
                        }
                    }

                    Button {
                        selectedCategoryForNewItem = category
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))

                            Text("Dodaj pozycję")
                                .font(.custom("WixMadeforDisplay-SemiBold", size: 16))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(20)
        .uberCardStyle()
    }

    private var totalItemsCount: Int {
        viewModel.categories.reduce(0) { partial, category in
            partial + viewModel.items(for: category.id).count
        }
    }
}

private struct MenuItemCard: View {
    let item: MenuItem
    let softFill: Color
    let mutedText: Color
    let accentGreen: Color
    let accentGreenText: Color
    let accentOrange: Color
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                itemImage

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.custom("WixMadeforDisplay-Bold", size: 20))
                        .foregroundStyle(.black)

                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.custom("WixMadeforDisplay-Regular", size: 14))
                            .foregroundStyle(mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let weight = item.weight, !weight.isEmpty {
                        Text(weight)
                            .font(.custom("WixMadeforDisplay-Medium", size: 13))
                            .foregroundStyle(mutedText)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 10) {
                    Text("\(Int(item.price)) zł")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                        .foregroundStyle(accentGreenText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(accentGreen.opacity(0.18))
                        .clipShape(Capsule())

                    if let oldPrice = item.oldPrice {
                        Text("\(Int(oldPrice)) zł")
                            .font(.custom("WixMadeforDisplay-Medium", size: 12))
                            .foregroundStyle(mutedText)
                            .strikethrough()
                    }

                    SwiftUI.Menu {
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
            }

            if hasTags {
                FlexibleTagWrap(spacing: 8, lineSpacing: 8) {
                    if item.isRecommended {
                        tagPill(
                            title: "Polecane",
                            foreground: accentGreenText,
                            background: accentGreen.opacity(0.18),
                            icon: "star.fill"
                        )
                    }

                    if item.isSpicy {
                        tagPill(
                            title: "Pikantne",
                            foreground: accentOrange,
                            background: accentOrange.opacity(0.14),
                            icon: "flame.fill"
                        )
                    }

                    if item.isVegetarian {
                        tagPill(
                            title: "Wege",
                            foreground: .green,
                            background: Color.green.opacity(0.14),
                            icon: "leaf.fill"
                        )
                    }

                    if !item.isAvailable {
                        tagPill(
                            title: "Niedostępne",
                            foreground: .red,
                            background: Color.red.opacity(0.12),
                            icon: "xmark.circle.fill"
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var hasTags: Bool {
        item.isRecommended || item.isSpicy || item.isVegetarian || !item.isAvailable
    }

    private func tagPill(title: String, foreground: Color, background: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))

            Text(title)
                .font(.custom("WixMadeforDisplay-Medium", size: 12))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(background)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var itemImage: some View {
        if let imageURL = item.imageURL,
           !imageURL.isEmpty,
           let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                        ProgressView()
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    placeholderImage

                @unknown default:
                    placeholderImage
                }
            }
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            placeholderImage
                .frame(width: 82, height: 82)
        }
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.04))

            Image(systemName: "fork.knife")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black.opacity(0.7))
        }
    }
}

private struct FlexibleTagWrap<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}

private struct UberCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 2)
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
