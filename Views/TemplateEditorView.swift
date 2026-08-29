//
//  TemplateEditorView.swift
//  SmartGradeScanner
//
//  هذه الشاشة هي إجابة على "غيرها" في طلب المستخدم: بدل الاقتصار على
//  تمبليت واحد جاهز، يقدر المستخدم يبني تمبليتاً جديداً بالكامل لأي
//  ورقة إجابة مختلفة (عدد أسئلة مختلف، عدد خيارات مختلف A-D أو A-E أو
//  صح/خطأ، عدد أعمدة مختلف) خلال ثوانٍ، ثم يطبع الورقة المطابقة له
//  (أو يصمم ورقته الخاصة بنفس التخطيط) ويبدأ المسح مباشرة.
//

import SwiftUI

struct TemplateEditorView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = "قالب جديد"
    @State private var questionCount = 20
    @State private var choiceCount = 4
    @State private var columns = 2
    @State private var pointsPerQuestion = 1.0
    @State private var includeName = true
    @State private var includeId = true

    private let choiceSets: [Int: [String]] = [
        2: ["✓", "✗"],
        3: ["A", "B", "C"],
        4: ["A", "B", "C", "D"],
        5: ["A", "B", "C", "D", "E"],
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("الاسم") {
                    TextField("اسم القالب", text: $name)
                }
                Section("بنية ورقة الإجابة") {
                    Stepper("عدد الأسئلة: \(questionCount)", value: $questionCount, in: 5...200, step: 5)
                    Stepper("عدد الخيارات لكل سؤال: \(choiceCount)", value: $choiceCount, in: 2...5)
                    Stepper("عدد الأعمدة: \(columns)", value: $columns, in: 1...4)
                    Stepper("نقاط لكل سؤال: \(pointsPerQuestion, specifier: "%.1f")",
                            value: $pointsPerQuestion, in: 0.5...10, step: 0.5)
                }
                Section("حقول الطالب") {
                    Toggle("حقل الاسم (OCR)", isOn: $includeName)
                    Toggle("حقل الرقم الجامعي (OCR)", isOn: $includeId)
                }
                Section {
                    Text("سيتم إنشاء ورقة إجابة قابلة للطباعة تطابق هذا القالب تماماً، بحيث يمكن مسحها مباشرة بعد الطباعة.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("قالب جديد")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                }
            }
        }
    }

    private func save() {
        let labels = choiceSets[choiceCount] ?? ["A", "B", "C", "D"]
        let template = ScanTemplate.generateGrid(
            name: name,
            questionCount: questionCount,
            choiceLabels: labels,
            columns: columns,
            pointsPerQuestion: pointsPerQuestion,
            includeNameField: includeName,
            includeIdField: includeId
        )
        try? templateStore.save(template)
        dismiss()
    }
}

#Preview {
    TemplateEditorView().environmentObject(TemplateStore())
}
