import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text("Racconto")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .tracking(2)

                VStack(spacing: 16) {
                    TextField("이메일", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)

                    SecureField("비밀번호", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await authViewModel.login(email: email, password: password) }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("로그인")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.primary)
                .foregroundStyle(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

                Button("계정이 없으신가요? 회원가입") {
                    showRegister = true
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 32)
            .sheet(isPresented: $showRegister) {
                RegisterView(authViewModel: authViewModel)
            }
        }
    }
}
