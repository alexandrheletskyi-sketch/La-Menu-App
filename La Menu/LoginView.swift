import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var currentNonce: String?
    @State private var appleSignInCoordinator: AppleSignInCoordinator?

    private let backgroundColor = Color.white
    private let fieldColor = Color(red: 0.96, green: 0.95, blue: 0.97)
    private let mutedText = Color.black.opacity(0.52)
    private let accentColor = Color(hex: "#FF5F2B")

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 64)

                        headerSection

                        Spacer()
                            .frame(height: 42)

                        formSection

                        Spacer()
                            .frame(height: 16)

                        errorSection

                        Spacer()
                            .frame(height: 20)

                        primaryButton

                        Spacer()
                            .frame(height: 18)

                        dividerSection

                        Spacer()
                            .frame(height: 18)

                        appleButton

                        Spacer()
                            .frame(height: 22)

                        modeSwitchButton

                        Spacer()
                            .frame(height: 32)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            Text(isSignUpMode ? "Stwórz swój profil" : "Wejdź do swojego profilu")
                .font(.wix(34, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(
                isSignUpMode
                ? "Załóż konto i zarządzaj swoim menu w jednym miejscu"
                : "Zaloguj się i zarządzaj swoim menu w jednym miejscu"
            )
            .font(.wix(17, weight: .medium))
            .foregroundStyle(mutedText)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 34, height: 8)

                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 18, height: 8)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Adres e-mail")
                    .font(.wix(15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)

                TextField(
                    "",
                    text: $email,
                    prompt: Text("Wpisz adres e-mail")
                        .font(.wix(18, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.22))
                )
                .font(.wix(18, weight: .medium))
                .foregroundColor(.black)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(height: 64)
                .background(fieldColor)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            VStack(spacing: 8) {
                Text("Hasło")
                    .font(.wix(15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)

                SecureField(
                    "",
                    text: $password,
                    prompt: Text("Wpisz hasło")
                        .font(.wix(18, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.22))
                )
                .font(.wix(18, weight: .medium))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(height: 64)
                .background(fieldColor)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = auth.errorMessage, !errorMessage.isEmpty {
            Text(errorMessage)
                .font(.wix(14, weight: .medium))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
        }
    }

    private var primaryButton: some View {
        Button {
            Task {
                if isSignUpMode {
                    await auth.signUp(email: email, password: password)
                } else {
                    await auth.signIn(email: email, password: password)
                }
            }
        } label: {
            Text(isSignUpMode ? "Stwórz profil" : "Zaloguj się")
                .font(.wix(20, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .disabled(auth.isLoading)
        .opacity(auth.isLoading ? 0.6 : 1)
    }

    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)

            Text("lub")
                .font(.wix(15, weight: .medium))
                .foregroundStyle(mutedText)

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var appleButton: some View {
        Button {
            startSignInWithApple()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "applelogo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Kontynuuj z Apple")
                    .font(.wix(18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
        .opacity(auth.isLoading ? 0.6 : 1)
    }

    private var modeSwitchButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSignUpMode.toggle()
            }
        } label: {
            Text(isSignUpMode ? "Masz już konto? Zaloguj się" : "Nie masz konta? Stwórz profil")
                .font(.wix(16, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func startSignInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let coordinator = AppleSignInCoordinator { result in
            Task {
                await handleAppleSignIn(result)
            }
        }

        appleSignInCoordinator = coordinator
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                await MainActor.run {
                    auth.errorMessage = "Nie udało się pobrać danych Apple ID"
                }
                return
            }

            guard let nonce = currentNonce else {
                await MainActor.run {
                    auth.errorMessage = "Brak nonce dla logowania Apple"
                }
                return
            }

            guard let identityToken = credential.identityToken else {
                await MainActor.run {
                    auth.errorMessage = "Apple nie zwróciło identity token"
                }
                return
            }

            guard let idTokenString = String(data: identityToken, encoding: .utf8) else {
                await MainActor.run {
                    auth.errorMessage = "Nie udało się odczytać identity token"
                }
                return
            }

            let givenName = credential.fullName?.givenName
            let familyName = credential.fullName?.familyName
            let email = credential.email

            await auth.signInWithApple(
                idToken: idTokenString,
                rawNonce: nonce,
                givenName: givenName,
                familyName: familyName,
                email: email
            )

        case .failure(let error):
            await MainActor.run {
                auth.errorMessage = error.localizedDescription
            }
        }
    }
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let onCompletion: (Result<ASAuthorization, Error>) -> Void

    init(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.onCompletion = onCompletion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow) ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion(.failure(error))
    }
}

// MARK: - Nonce helpers

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)

    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        let randoms: [UInt8] = (0..<16).map { _ in
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)

            if status != errSecSuccess {
                fatalError("Unable to generate nonce. OSStatus \(status)")
            }

            return random
        }

        for random in randoms {
            if remainingLength == 0 { break }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.map { String(format: "%02x", $0) }.joined()
}

// MARK: - Font

extension Font {
    static func wix(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String

        switch weight {
        case .bold:
            fontName = "WixMadeforDisplay-Bold"
        case .semibold:
            fontName = "WixMadeforDisplay-SemiBold"
        case .medium:
            fontName = "WixMadeforDisplay-Medium"
        default:
            fontName = "WixMadeforDisplay-Regular"
        }

        return .custom(fontName, size: size)
    }
}

// MARK: - Color

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6:
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8:
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
