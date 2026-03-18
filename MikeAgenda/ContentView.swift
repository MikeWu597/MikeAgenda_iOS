//
//  ContentView.swift
//  MikeAgenda
//
//  Created by MikeWu597 on 2026/3/17.
//

import SwiftUI

struct ContentView: View {
    @State private var profile = ConnectionProfileStore.load()

    var body: some View {
        MikeAgendaWebView(profile: profile, onProfileChanged: {
            profile = ConnectionProfileStore.load()
        })
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
}
