import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var currentNonce: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 10) {
                    Text("La Menu")
                        .font(.system(size: 34, weight: .bold))

                    Text("Create and manage your restaurant menu")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if let errorMessage = auth.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        if isSignUpMode {
                            await auth.signUp(email: email, password: password)
                        } else {
                            await auth.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    Text(isSignUpMode ? "Create account" : "Log in")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(auth.isLoading)

                SignInWithAppleButton(
                    isSignUpMode ? .signUp : .signIn,
                    onRequest: { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce

                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    },
                    onCompletion: { result in
                        Task {
                            await handleAppleSignIn(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .disabled(auth.isLoading)

                Button {
                    isSignUpMode.toggle()
                } label: {
                    Text(isSignUpMode ? "Already have an account? Log in" : "No account? Sign up")
                        .foregroundStyle(.black)
                }

                Spacer()
            }
            .padding(24)
            .navigationBarHidden(true)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                await MainActor.run {
                    auth.errorMessage = "Nie udało się pobrać danych Apple ID."
                }
                return
            }

            guard let nonce = currentNonce else {
                await MainActor.run {
                    auth.errorMessage = "Brak nonce dla logowania Apple."
                }
                return
            }

            guard let identityToken = credential.identityToken else {
                await MainActor.run {
                    auth.errorMessage = "Apple nie zwróciło identity token."
                }
                return
            }

            guard let idTokenString = String(data: identityToken, encoding: .utf8) else {
                await MainActor.run {
                    auth.errorMessage = "Nie udało się odczytać identity token."
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
