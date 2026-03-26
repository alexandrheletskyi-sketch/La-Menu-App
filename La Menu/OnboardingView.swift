import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var step: OnboardingStep = .basicInfo
    @State private var draft = OnboardingDraft()

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                progressSection

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        currentStepView
                    }
                    .padding(20)
                }

                bottomBar
            }
            .background(Color(.systemBackground))
            .navigationBarBackButtonHidden(true)
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            selectedImageData = try? await selectedPhoto.loadTransferable(type: Data.self)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.largeTitle.bold())

            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var progressSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color.black : Color.black.opacity(0.12))
                        .frame(height: 8)
                }
            }

            HStack {
                Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .basicInfo:
            BasicInfoStepView(
                businessName: $draft.businessName,
                description: $draft.description,
                address: $draft.address,
                phone: $draft.phone,
                selectedPhoto: $selectedPhoto,
                selectedImageData: $selectedImageData
            )

        case .publicLink:
            PublicLinkStepView(username: $draft.username)

        case .openingHours:
            OpeningHoursStepView(days: $draft.days)

        case .firstMenu:
            FirstMenuStepView(
                menuTitle: $draft.menuTitle,
                categoryName: $draft.categoryName,
                firstItemName: $draft.firstItemName,
                firstItemDescription: $draft.firstItemDescription,
                firstItemPrice: $draft.firstItemPrice
            )

        case .finish:
            FinishStepView(draft: draft)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let errorMessage = auth.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                if step.rawValue > 0 {
                    Button {
                        withAnimation(.easeInOut) {
                            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .basicInfo
                        }
                    } label: {
                        Text("Back")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }

                Button {
                    Task {
                        await nextAction()
                    }
                } label: {
                    Text(step == .finish ? (auth.isLoading ? "Creating..." : "Create workspace") : "Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isCurrentStepValid ? Color.black : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(!isCurrentStepValid || auth.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
        )
    }

    private var isCurrentStepValid: Bool {
        switch step {
        case .basicInfo:
            return draft.businessName.trimmed.count >= 2 && draft.address.trimmed.count >= 3

        case .publicLink:
            return draft.username.slugified.count >= 3

        case .openingHours:
            return draft.days.contains(where: { !$0.isClosed })

        case .firstMenu:
            return draft.menuTitle.trimmed.count >= 2 &&
                   draft.categoryName.trimmed.count >= 2 &&
                   draft.firstItemName.trimmed.count >= 2 &&
                   Double(draft.firstItemPrice.replacingOccurrences(of: ",", with: ".")) != nil

        case .finish:
            return true
        }
    }

    private func nextAction() async {
        if step == .finish {
            await auth.completeOnboarding(draft: draft)
        } else {
            withAnimation(.easeInOut) {
                step = OnboardingStep(rawValue: step.rawValue + 1) ?? .finish
            }
        }
    }
}

private struct BasicInfoStepView: View {
    @Binding var businessName: String
    @Binding var description: String
    @Binding var address: String
    @Binding var phone: String
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var selectedImageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: 12) {
                            if let selectedImageData,
                               let uiImage = UIImage(data: selectedImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 94, height: 94)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.black.opacity(0.06))
                                    .frame(width: 94, height: 94)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.title3)
                                            .foregroundStyle(.black)
                                    )
                            }

                            Text("Add logo")
                                .font(.headline)

                            Text("You can change it later")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            card {
                VStack(spacing: 14) {
                    field("Business name", text: $businessName)
                    field("Short description", text: $description)
                    field("Address", text: $address)
                    field("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
        }
    }
}

private struct PublicLinkStepView: View {
    @Binding var username: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your link")
                        .font(.headline)

                    field("Username", text: $username)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("lamenu.app/\(username.slugified.isEmpty ? "your-name" : username.slugified)")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }
}

private struct OpeningHoursStepView: View {
    @Binding var days: [DayHoursDraft]

    var body: some View {
        VStack(spacing: 14) {
            Button {
                applySameHoursToAll()
            } label: {
                Text("Apply first day hours to all")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            ForEach($days) { $day in
                card {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(day.title)
                                .font(.headline)

                            Spacer()

                            Toggle("Closed", isOn: $day.isClosed)
                                .labelsHidden()
                        }

                        if !day.isClosed {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Open")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    DatePicker(
                                        "",
                                        selection: $day.openDate,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Close")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    DatePicker(
                                        "",
                                        selection: $day.closeDate,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func applySameHoursToAll() {
        guard let firstOpen = days.first?.openDate,
              let firstClose = days.first?.closeDate,
              let firstClosed = days.first?.isClosed else { return }

        for index in days.indices {
            days[index].openDate = firstOpen
            days[index].closeDate = firstClose
            days[index].isClosed = firstClosed
        }
    }
}

private struct FirstMenuStepView: View {
    @Binding var menuTitle: String
    @Binding var categoryName: String
    @Binding var firstItemName: String
    @Binding var firstItemDescription: String
    @Binding var firstItemPrice: String

    var body: some View {
        VStack(spacing: 18) {
            card {
                VStack(spacing: 14) {
                    field("Menu title", text: $menuTitle)
                    field("First category", text: $categoryName)
                    field("First item name", text: $firstItemName)
                    field("Item description", text: $firstItemDescription)
                    field("Price", text: $firstItemPrice)
                        .keyboardType(.decimalPad)
                }
            }
        }
    }
}

private struct FinishStepView: View {
    let draft: OnboardingDraft

    var body: some View {
        VStack(spacing: 16) {
            summaryCard(
                title: "Business",
                rows: [
                    ("Name", draft.businessName),
                    ("Address", draft.address),
                    ("Phone", draft.phone.isEmpty ? "—" : draft.phone)
                ]
            )

            summaryCard(
                title: "Public link",
                rows: [
                    ("Link", "lamenu.app/\(draft.username.slugified)")
                ]
            )

            summaryCard(
                title: "First menu",
                rows: [
                    ("Menu", draft.menuTitle),
                    ("Category", draft.categoryName),
                    ("Item", draft.firstItemName),
                    ("Price", "\(draft.firstItemPrice) zł")
                ]
            )
        }
    }

    private func summaryCard(title: String, rows: [(String, String)]) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)

                ForEach(rows, id: \.0) { row in
                    HStack(alignment: .top) {
                        Text(row.0)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(row.1)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

private func field(_ title: String, text: Binding<String>) -> some View {
    TextField(title, text: text)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
}

private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var slugified: String {
        trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-+|-+$", with: "", options: .regularExpression)
    }
}
