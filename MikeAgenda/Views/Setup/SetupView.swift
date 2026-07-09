import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var sessionService: SessionService
    @State private var domain = ""
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

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.blue.gradient)
                        Text("MikeAgenda")
                            .font(.system(size: 28, weight: .bold))
                        Text("配置服务器连接")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 16) {
                        glassField(icon: "link", title: "服务器地址", text: $domain, placeholder: "https://agenda.example.com")
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        glassField(icon: "person", title: "账户名", text: $username, placeholder: "请输入账户名")
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        glassField(icon: "lock", title: "密码", text: $password, placeholder: "请输入密码", isSecure: true)
                            .textContentType(.password)

                        if resolvedURL != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("将连接到 \(resolvedURL!)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        save()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            }
                            Text(isLoading ? "连接中..." : "保存并进入")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isValid ? Color.blue : Color.gray.opacity(0.3))
                        )
                    }
                    .disabled(isLoading || !isValid)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            let profile = ConnectionProfileStore.load()
            domain = profile.domain
            username = profile.username
            password = profile.password
        }
    }

    private func glassField(icon: String, title: String, text: Binding<String>, placeholder: String, isSecure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Group {
                    if isSecure {
                        SecureField(placeholder, text: text)
                    } else {
                        TextField(placeholder, text: text)
                    }
                }
                .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    private var resolvedURL: String? {
        let raw = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let candidate = raw.contains("://") ? raw : "https://\(raw)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil
        return components?.url?.absoluteString
    }

    private var isValid: Bool {
        !domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        resolvedURL != nil
    }

    private func save() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        ConnectionProfileStore.save(ConnectionProfile(
            domain: domain.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        ))
        sessionService.clear()
        sessionService.notifyProfileChanged()
        isLoading = false
    }
}
