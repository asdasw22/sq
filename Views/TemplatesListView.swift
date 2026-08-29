//
//  TemplatesListView.swift
//  SmartGradeScanner
//

import SwiftUI

struct TemplatesListView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(templateStore.templates) { template in
                    NavigationLink {
                        TemplateDetailView(template: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)

                            Text("\(template.questionGroups.count) سؤال · \(Int(template.totalPoints)) نقطة · حقول: \(template.studentInfoFields.map(\.displayName).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("القوالب")
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                TemplateEditorView()
            }
            .overlay {
                if templateStore.templates.isEmpty {
                    ContentUnavailableView(
                        "لا توجد قوالب بعد",
                        systemImage: "square.grid.2x2",
                        description: Text("أنشئ قالباً جديداً بالضغط على +")
                    )
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? templateStore.delete(templateStore.templates[index])
        }
    }
}


struct TemplateDetailView: View {
    let template: ScanTemplate
    
    @EnvironmentObject private var answerKeyStore: AnswerKeyStore
    @State private var showAnswerKeyEditor = false

    var body: some View {
        List {
            Section("معلومات") {
                LabeledContent(
                    "عدد الأسئلة",
                    value: "\(template.questionGroups.count)"
                )

                LabeledContent(
                    "مجموع النقاط",
                    value: "\(Int(template.totalPoints))"
                )

                LabeledContent(
                    "عتبة الاسوداد",
                    value: String(format: "%.0f%%", template.fillThreshold * 100)
                )
            }

            Section("مفتاح الإجابة") {
                if let key = answerKeyStore.key(for: template.id) {
                    Text("محفوظ (\(key.correctAnswers.count) إجابة) - \(key.name)")
                } else {
                    Text("لا يوجد مفتاح إجابة بعد")
                        .foregroundStyle(.secondary)
                }

                Button("تحرير مفتاح الإجابة") {
                    showAnswerKeyEditor = true
                }
            }

            Section("الحقول النصية") {
                ForEach(template.studentInfoFields) { field in
                    Text(field.displayName)
                }
            }
        }
        .navigationTitle(template.name)
        .sheet(isPresented: $showAnswerKeyEditor) {
            AnswerKeyEditorView(template: template)
        }
    }
}


#Preview {
    TemplatesListView()
        .environmentObject(TemplateStore())
        .environmentObject(AnswerKeyStore())
}
