//
//  SettingsView.swift
//  SmartGradeScanner
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @EnvironmentObject private var resultsStore: ResultsStore
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("حول") {
                    LabeledContent("التطبيق", value: "SmartGradeScanner")
                    LabeledContent("عدد القوالب", value: "\(templateStore.templates.count)")
                    LabeledContent("عدد النتائج المحفوظة", value: "\(resultsStore.results.count)")
                }
                Section("كيف يعمل الكشف؟") {
                    Text("""
كل قالب يحدد عتبة اسوداد (fillThreshold) خاصة به يمكن تعديلها من شاشة \
تفاصيل القالب لاحقاً. كلما زادت العتبة، وجب ملء الفقاعة بشكل أوضح كي \
تُعتبر "مملوءة". القيمة الافتراضية 45% تناسب معظم الحالات (قلم رصاص \
أو أسود غامق).
""")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Section("بيانات") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Text("حذف كل النتائج المحفوظة")
                    }
                }
            }
            .navigationTitle("الإعدادات")
            .alert("حذف كل النتائج؟", isPresented: $showResetAlert) {
                Button("إلغاء", role: .cancel) {}
                Button("حذف", role: .destructive) {
                    for result in resultsStore.results {
                        try? resultsStore.delete(result)
                    }
                }
            } message: {
                Text("لا يمكن التراجع عن هذا الإجراء.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TemplateStore())
        .environmentObject(ResultsStore())
}
