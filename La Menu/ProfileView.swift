import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundStyle(.black)
                        )

                    Text("Profile")
                        .font(.title2.bold())

                    Text("Manage account and app settings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 30)

                Button {
                    Task {
                        await auth.signOut()
                    }
                } label: {
                    Text("Log out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Profile")
        }
    }
}
