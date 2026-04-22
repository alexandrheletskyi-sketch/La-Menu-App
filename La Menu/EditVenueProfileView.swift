import SwiftUI
import PhotosUI

struct EditVenueProfileView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = EditProfileViewModel()
    @State private var logoPhoto: PhotosPickerItem?
    @State private var logoImageData: Data?

    private var accentColor: Color {
        Color(lmHex: viewModel.draft.accentColorHex)
    }

    private var accentSoft: Color {
        Color(lmHex: viewModel.draft.accentColorHex).opacity(0.14)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.white
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            BasicInfoStepView(
                                businessName: binding(\.businessName),
                                address: binding(\.address),
                                phone: binding(\.phone),
                                logoPhoto: $logoPhoto,
                                logoImageData: $logoImageData
                            )

                            EditPublicLinkSection(
                                username: binding(\.username),
                                accentSoft: accentSoft,
                                validationState: viewModel.usernameValidationState,
                                isBusy: viewModel.isLoading || viewModel.isSaving,
                                onUsernameChanged: {
                                    viewModel.usernameDidChange()
                                },
                                onCheckNow: {
                                    await viewModel.validateUsernameAvailability()
                                }
                            )

                            BrandColorStepView(
                                accentColorHex: binding(\.accentColorHex)
                            )

                            LegalDetailsStepView(
                                legalBusinessName: binding(\.legalBusinessName),
                                businessDisplayName: binding(\.businessDisplayName),
                                nip: binding(\.nip),
                                addressLine1: binding(\.addressLine1),
                                addressLine2: binding(\.addressLine2),
                                postalCode: binding(\.postalCode),
                                city: binding(\.city),
                                country: binding(\.country),
                                contactEmail: binding(\.contactEmail),
                                contactPhone: binding(\.contactPhone),
                                complaintEmail: binding(\.complaintEmail),
                                complaintPhone: binding(\.complaintPhone)
                            )

                            FulfillmentStepView(
                                pickupAvailable: binding(\.pickupAvailable),
                                deliveryAvailable: binding(\.deliveryAvailable),
                                deliveryArea: binding(\.deliveryArea),
                                deliveryPricePerKm: binding(\.deliveryPricePerKm),
                                cashPaymentAvailable: binding(\.cashPaymentAvailable),
                                cardPaymentAvailable: binding(\.cardPaymentAvailable),
                                blikPaymentAvailable: binding(\.blikPaymentAvailable),
                                accentColor: accentColor
                            )

                            OpeningHoursStepView(
                                days: binding(\.days),
                                accentColor: accentColor
                            )

                            OrderSettingsStepView(
                                isAcceptingOrders: binding(\.isAcceptingOrders),
                                smsConfirmationEnabled: binding(\.smsConfirmationEnabled),
                                slotIntervalMinutes: binding(\.slotIntervalMinutes),
                                accentColor: accentColor
                            )

                            Spacer()
                                .frame(height: 90)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                    }
                }

                bottomBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: auth.profile?.id) {
                viewModel.configure(profileId: auth.profile?.id)
                await viewModel.load()
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.wix(13, wixWeight: .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let successMessage = viewModel.successMessage, !successMessage.isEmpty {
                Text(successMessage)
                    .font(.wix(13, wixWeight: .medium))
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                Button {
                    guard !viewModel.isSaving else { return }
                    dismiss()
                } label: {
                    Text("Anuluj")
                        .font(.wix(16, wixWeight: .semiBold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(viewModel.isSaving)

                Button {
                    Task {
                        await viewModel.save()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.9)
                        }

                        Text(viewModel.isSaving ? "Zapisywanie..." : "Zapisz")
                            .font(.wix(16, wixWeight: .semiBold))
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(viewModel.canSave ? accentColor : Color.black.opacity(0.16))
                    )
                }
                .disabled(!viewModel.canSave || viewModel.isSaving || viewModel.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .background(
            Rectangle()
                .fill(Color.white)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 1)
                }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<OnboardingDraft, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.draft[keyPath: keyPath] },
            set: { viewModel.draft[keyPath: keyPath] = $0 }
        )
    }
}

private struct EditPublicLinkSection: View {
    @Binding var username: String
    let accentSoft: Color
    let validationState: EditProfileViewModel.UsernameValidationState
    let isBusy: Bool
    let onUsernameChanged: () -> Void
    let onCheckNow: () async -> Void

    private var preview: String {
        username.slugified.isEmpty ? "twoj-lokal" : username.slugified
    }

    private var helperText: String {
        switch validationState {
        case .idle:
            return "Użyj małych liter, cyfr i myślników"
        case .typing:
            return "Za chwilę sprawdzimy dostępność linku"
        case .checking:
            return "Sprawdzanie dostępności..."
        case .available:
            return "Ten link jest dostępny"
        case .taken:
            return "Ten link jest już zajęty"
        case .invalid(let message):
            return message
        case .error(let message):
            return message
        }
    }

    private var helperColor: Color {
        switch validationState {
        case .available:
            return .green
        case .taken, .invalid, .error:
            return .red
        default:
            return .black.opacity(0.48)
        }
    }

    private var borderColor: Color {
        switch validationState {
        case .available:
            return .green.opacity(0.25)
        case .taken, .invalid, .error:
            return .red.opacity(0.25)
        default:
            return .clear
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Link publiczny",
                subtitle: "Tutaj możesz zmienić publiczny adres swojego lokalu"
            ) {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        LMInputField(title: "Nazwa w linku", text: usernameProxy)

                        HStack(spacing: 8) {
                            if case .checking = validationState {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }

                            Text(helperText)
                                .font(.wix(13, wixWeight: .medium))
                                .foregroundStyle(helperColor)

                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Podgląd")
                            .font(.wix(13, wixWeight: .medium))
                            .foregroundStyle(.black.opacity(0.45))

                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)

                            Text("lamenu.pl/\(preview)")
                                .font(.wix(18, wixWeight: .semiBold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer()
                        }
                        .padding(16)
                        .background(accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
        }
        .task(id: username) {
            guard !isBusy else { return }

            let normalized = username.slugified
            guard !normalized.isEmpty else { return }
            guard normalized.count >= 3 else { return }

            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            guard !isBusy else { return }

            await onCheckNow()
        }
    }

    private var usernameProxy: Binding<String> {
        Binding(
            get: { username },
            set: { newValue in
                username = newValue
                onUsernameChanged()
            }
        )
    }
}
