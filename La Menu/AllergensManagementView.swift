import SwiftUI
import Supabase
import PostgREST

struct VenueAllergenRow: Identifiable, Hashable {
    let id: UUID
    var code: String
    var title: String
    var description: String

    init(
        id: UUID = UUID(),
        code: String = "",
        title: String = "",
        description: String = ""
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
    }
}

struct AllergensManagementView: View {
    let profileId: UUID

    @Environment(\.dismiss) private var dismiss

    @State private var allergens: [VenueAllergenRow] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private let pageBackground = Color.white
    private let softFill = Color.black.opacity(0.04)
    private let mutedText = Color.black.opacity(0.58)
    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)

    var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    infoCard

                    if let errorMessage, !errorMessage.isEmpty {
                        errorCard(message: errorMessage)
                    }

                    if isLoading && !didLoad {
                        loadingCard
                    } else {
                        VStack(spacing: 12) {
                            ForEach($allergens) { $allergen in
                                allergenCard(allergen: $allergen)
                            }
                        }

                        Button {
                            allergens.append(
                                VenueAllergenRow(
                                    code: "\(suggestedNextCode())",
                                    title: "",
                                    description: ""
                                )
                            )
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Dodaj alergen")
                                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await saveAllergens()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(isSaving ? "Zapisywanie..." : "Zapisz tabelę alergenów")
                                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !didLoad else { return }
            await loadAllergens()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }

            Text("Tabela alergenów")
                .font(.custom("WixMadeforDisplay-Bold", size: 38))
                .foregroundStyle(.black)

            Text("Dodaj alergeny dla swojego lokalu. Później będzie można je wyświetlać przy każdej pozycji menu po kliknięciu przycisku.")
                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accentOrange.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accentOrange)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Jak to będzie działać")
                        .font(.custom("WixMadeforDisplay-Bold", size: 20))
                        .foregroundStyle(.black)

                    Text("Każdy alergen może mieć numer, nazwę i opis. Potem pozycje menu będą mogły pokazywać przycisk „Tabela alergenów”.")
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .profileCardStyle()
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text("Ładowanie tabeli alergenów...")
                .font(.custom("WixMadeforDisplay-Regular", size: 15))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .profileCardStyle()
    }

    private func errorCard(message: String) -> some View {
        Text(message)
            .font(.custom("WixMadeforDisplay-Regular", size: 14))
            .foregroundStyle(.red.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func allergenCard(allergen: Binding<VenueAllergenRow>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Alergen")
                    .font(.custom("WixMadeforDisplay-Bold", size: 20))
                    .foregroundStyle(.black)

                Spacer()

                Button(role: .destructive) {
                    allergens.removeAll { $0.id == allergen.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(width: 38, height: 38)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                field(
                    title: "Numer",
                    text: allergen.code,
                    placeholder: "np. 1"
                )

                field(
                    title: "Nazwa",
                    text: allergen.title,
                    placeholder: "np. Gluten"
                )
            }

            field(
                title: "Opis",
                text: allergen.description,
                placeholder: "np. Zboża zawierające gluten"
            )
        }
        .padding(18)
        .profileCardStyle()
    }

    private func field(
        title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("WixMadeforDisplay-Medium", size: 13))
                .foregroundStyle(.black.opacity(0.55))

            TextField(placeholder, text: text)
                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(softFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func loadAllergens() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
            didLoad = true
        }

        do {
            let records: [VenueAllergenRecord] = try await SupabaseManager.shared
                .from("venue_allergens")
                .select()
                .eq("profile_id", value: profileId.uuidString)
                .order("sort_order", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value

            allergens = records.map {
                VenueAllergenRow(
                    id: $0.id,
                    code: $0.code,
                    title: $0.title,
                    description: $0.description ?? ""
                )
            }

            if allergens.isEmpty {
                allergens = [
                    VenueAllergenRow(code: "1", title: "Gluten", description: "Zboża zawierające gluten"),
                    VenueAllergenRow(code: "2", title: "Skorupiaki", description: "Skorupiaki i produkty pochodne"),
                    VenueAllergenRow(code: "3", title: "Jaja", description: "Jaja i produkty pochodne")
                ]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAllergens() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let cleanedRows = allergens
                .map {
                    VenueAllergenRow(
                        id: $0.id,
                        code: $0.code.trimmingCharacters(in: .whitespacesAndNewlines),
                        title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: $0.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter {
                    !$0.code.isEmpty && !$0.title.isEmpty
                }

            try await SupabaseManager.shared
                .from("venue_allergens")
                .delete()
                .eq("profile_id", value: profileId.uuidString)
                .execute()

            if !cleanedRows.isEmpty {
                let payload = cleanedRows.enumerated().map { index, row in
                    InsertVenueAllergen(
                        profile_id: profileId,
                        code: row.code,
                        title: row.title,
                        description: row.description.isEmpty ? nil : row.description,
                        sort_order: index
                    )
                }

                try await SupabaseManager.shared
                    .from("venue_allergens")
                    .insert(payload)
                    .execute()
            }

            allergens = cleanedRows
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func suggestedNextCode() -> Int {
        let numericCodes = allergens.compactMap { Int($0.code.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return (numericCodes.max() ?? 0) + 1
    }
}
