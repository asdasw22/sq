//
//  ContentView.swift
//  SmartGradeScanner
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanHomeView()
                .tabItem { Label("مسح", systemImage: "camera.viewfinder") }
                .tag(0)

            TemplatesListView()
                .tabItem { Label("القوالب", systemImage: "square.grid.2x2") }
                .tag(1)

            HistoryView()
                .tabItem { Label("السجل", systemImage: "clock.arrow.circlepath") }
                .tag(2)

            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape") }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TemplateStore())
        .environmentObject(ResultsStore())
        .environmentObject(AnswerKeyStore())
}
