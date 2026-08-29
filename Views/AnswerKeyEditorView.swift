//
//  AnswerKeyEditorView.swift
//  SmartGradeScanner
//

import SwiftUI

struct AnswerKeyEditorView: View {
    let template: ScanTemplate
    @EnvironmentObject private var answerKeyStore: AnswerKeyStore
    @Environment(\.dismiss) private var dismiss

    @State private var answers: [Int: String] = [:]
    @State private var keyName = "مفتاح الإجابة"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("اسم المفتاح", text: $keyName)
                }
                Section("اختر الإجابة الصحيحة لكل سؤال") {
                    ForEach(template.questionGroups.sorted { $0.questionNumber < $1.questionNumber }) { group in
                        Picker("سؤال \(group.questionNumber)", selection: binding(for: group.questionNumber)) {
                            Text("—").tag("")
                            ForEach(group.choices, id: \.id) { choice in
                                Text(choice.label).tag(choice.label)
                            }
                        }
                    }
                }
            }
            .navigationTitle("مفتاح الإجابة")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                }
            }
            .onAppear {
                if let existing = answerKeyStore.key(for: template.id) {
                    answers = existing.correctAnswers
                    keyName = existing.name
                }
            }
        }
    }

    private func binding(for question: Int) -> Binding<String> {
        Binding(
            get: { answers[question] ?? "" },
            set: { answers[question] = $0.isEmpty ? nil : $0 }
        )
    }

    private func save() {
        let key = AnswerKey(id: answerKeyStore.key(for: template.id)?.id ?? UUID(),
                             templateId: template.id, name: keyName,
                             correctAnswers: answers.filter { !$0.value.isEmpty })
        try? answerKeyStore.save(key)
        dismiss()
    }
}
