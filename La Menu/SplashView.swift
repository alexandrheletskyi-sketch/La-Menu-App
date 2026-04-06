import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.38, blue: 0.18)
                .ignoresSafeArea()

            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240)
                .padding(.horizontal, 32)
        }
    }
}
