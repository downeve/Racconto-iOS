import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var registered = false

    var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if registered {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("이메일을 확인해주세요")
                            .font(.title3)
                            .fontWeight(.medium)
                        Text("가입한 이메일로 인증 링크를 보냈습니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("확인") { dismiss() }
                            .padding(.top, 8)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        TextField("이름 (선택)", text: $name)
                            .textContentType(.name)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Radius.large)

                        TextField("이메일", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Radius.large)

                        SecureField("비밀번호", text: $password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Radius.large)
                    }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await authViewModel.register(
                                email: email,
                                password: password,
                                name: name.isEmpty ? nil : name
                            )
                            if authViewModel.errorMessage == nil {
                                registered = true
                            }
                        }
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("회원가입")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.primary)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .cornerRadius(Radius.large)
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                }
            }
            .padding(.horizontal, 32)
            .navigationTitle("회원가입")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
