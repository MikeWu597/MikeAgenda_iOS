//
//  ContentView.swift
//  MikeAgenda
//
//  Created by MikeWu597 on 2026/3/17.
//

import SwiftUI

struct ContentView: View {
    @State private var profile = ConnectionProfileStore.load()
    @State private var draftProfile = ConnectionProfileStore.load()
    @State private var isConfigurationPresented = false

    var body: some View {
        Group {
            if profile.isComplete {
                ZStack(alignment: .bottomTrailing) {
                    MikeAgendaWebView(profile: profile)
                        .id(profile.reloadToken)
                        .ignoresSafeArea()

                    Button(action: openConfiguration) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Color.black.opacity(0.7)))
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                    .accessibilityLabel("连接设置")
                }
            } else {
                NavigationStack {
                    ConnectionConfigurationView(
                        profile: $draftProfile,
                        isInitialSetup: true,
                        onSave: saveProfile,
                        onClear: nil,
                        onCancel: nil
                    )
                }
            }
        }
        .sheet(isPresented: $isConfigurationPresented) {
            NavigationStack {
                ConnectionConfigurationView(
                    profile: $draftProfile,
                    isInitialSetup: false,
                    onSave: saveProfile,
                    onClear: clearProfile,
                    onCancel: closeConfiguration
                )
            }
        }
    }

    private func openConfiguration() {
        draftProfile = profile
        isConfigurationPresented = true
    }

    private func closeConfiguration() {
        isConfigurationPresented = false
    }

    private func saveProfile() {
        let didChange = draftProfile.reloadToken != profile.reloadToken

        ConnectionProfileStore.save(draftProfile)
        if didChange {
            ConnectionProfileStore.clearWebCookies()
        }

        profile = ConnectionProfileStore.load()
        draftProfile = profile
        isConfigurationPresented = false
    }

    private func clearProfile() {
        ConnectionProfileStore.clear()
        profile = ConnectionProfile()
        draftProfile = profile
        isConfigurationPresented = false
    }
}

private struct ConnectionConfigurationView: View {
    @Binding var profile: ConnectionProfile

    let isInitialSetup: Bool
    let onSave: () -> Void
    let onClear: (() -> Void)?
    let onCancel: (() -> Void)?

    private var normalizedAddress: String? {
        profile.normalizedBaseURL?.absoluteString
    }

    private var validationMessage: String? {
        if profile.trimmedDomain.isEmpty {
            return "请输入域名或完整地址。"
        }

        if profile.normalizedBaseURL == nil {
            return "地址格式无效，请输入类似 https://agenda.example.com 的完整地址。"
        }

        if profile.trimmedUsername.isEmpty {
            return "请输入账户名。"
        }

        if profile.password.isEmpty {
            return "请输入密码。"
        }

        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isInitialSetup ? "配置 MikeAgenda" : "修改连接")
                        .font(.system(size: 30, weight: .bold))
                    Text("App 内页面直接使用原仓库的前端代码，接口再转发到你配置的远程服务端。")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                Group {
                    Text("域名")
                        .font(.system(size: 15, weight: .semibold))
                    TextField("例如 https://agenda.example.com", text: $profile.domain)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    Text("账户名")
                        .font(.system(size: 15, weight: .semibold))
                    TextField("请输入账户名", text: $profile.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    Text("密码")
                        .font(.system(size: 15, weight: .semibold))
                    SecureField("请输入密码", text: $profile.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }

                if let normalizedAddress {
                    Text("当前将转发到 \(normalizedAddress)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }

                Button(action: onSave) {
                    Text(isInitialSetup ? "保存并进入" : "保存")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationMessage != nil)

                if let onClear {
                    Button(role: .destructive, action: onClear) {
                        Text("清除已保存连接")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onCancel, !isInitialSetup {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: onCancel)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
