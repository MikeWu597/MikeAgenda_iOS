import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionService: SessionService
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.15), .purple.opacity(0.1), .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.blue.gradient)
                    Text("欢迎回来")
                        .font(.system(size: 28, weight: .bold))
                    Text("登录 MikeAgenda")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        TextField("请输入用户名", text: $username)
                            .font(.system(size: 16))
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                            )
                    )

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        SecureField("请输入密码", text: $password)
                            .font(.system(size: 16))
                            .textContentType(.password)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
                .padding(.horizontal, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                Button {
                    login()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(isLoading ? "登录中..." : "登录")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill((!username.isEmpty && !password.isEmpty) ? Color.blue : Color.gray.opacity(0.3))
                    )
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .task {
            await silentLogin()
        }
    }

    private func silentLogin() async {
        guard let session = sessionService.session, !session.isEmpty else { return }
        do {
            _ = try await APIClient.shared.getItems()
            sessionService.isAuthenticated = true
        } catch {
            sessionService.clear()
        }
    }

    private func login() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let token = try await APIClient.shared.login(username: username, password: password)
                await MainActor.run {
                    sessionService.save(token)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
