//
//  ContentView.swift
//  MikeAgenda
//
//  Created by MikeWu597 on 2026/3/17.
//

import SwiftUI

struct ContentView: View {
    @State private var profile = ConnectionProfileStore.load()
    @State private var colorScheme: ColorScheme? = {
        switch ConnectionProfileStore.loadColorMode() {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }()

    var body: some View {
        MikeAgendaWebView(profile: profile, onProfileChanged: {
            profile = ConnectionProfileStore.load()
        }, onColorModeChanged: { mode in
            ConnectionProfileStore.saveColorMode(mode)
            switch mode {
            case "light": colorScheme = .light
            case "dark": colorScheme = .dark
            default: colorScheme = nil
            }
        })
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(colorScheme)
    }
}

#Preview {
    ContentView()
}
