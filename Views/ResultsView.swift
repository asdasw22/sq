//
//  ResultsView.swift
//  SmartGradeScanner
//
//  تعرض الصورة المصححة (بعد المحاذاة) مع تراكب دوائر ملوّنة فوق كل
//  فقاعة: أخضر = صحيحة، أحمر = خاطئة، رمادي = فارغة، برتقالي = غامضة
//  (تحتاج مراجعة). يمكن للمستخدم لمس أي سؤال لتصحيحه يدوياً إن أخطأ
//  الكشف التلقائي - وهذا ضروري عملياً لأي أداة OMR واقعية.
//

import SwiftUI
import CoreGraphics

struct ResultsView: View {
    @EnvironmentObject private var resultsStore: ResultsStore
    @EnvironmentObject private var templateStore: TemplateStore
    @EnvironmentObject private var answerKeyStore: AnswerKeyStore

    @State var result: GradeResult
    let alignedImage: CGImage

    @State private var showManualEditFor: Int?
    @State private var showExportSheet = false

    private var template: ScanTemplate? {
        templateStore.templates.first { $0.id == result.templateId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreHeader

                if let template {
                    GeometryReader { geo in
                        let imgAspect = CGFloat(alignedImage.width) / CGFloat(alignedImage.height)
                        let displayWidth = geo.size.width
                        let displayHeight = displayWidth / imgAspect

                        ZStack {
                            Image(decorative: alignedImage, scale: 1, orientation: .up)
                                .resizable()
                                .frame(width: displayWidth, height: displayHeight)

                            ForEach(result.answers) { answer in
                                bubbleOverlay(for: answer, template: template,
                                              displaySize: CGSize(width: displayWidth, height: displayHeight))
                            }
                        }
                        .frame(width: displayWidth, height: displayHeight)
                    }
                    .aspectRatio(CGFloat(alignedImage.width) / CGFloat(alignedImage.height), contentMode: .fit)
                    .padding(.horizontal)
                }

                studentInfoSection

                answersListSection

                Button {
                    showExportSheet = true
                } label: {
                    Label("مشاركة/تصدير", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("النتيجة")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) {
            if let url = CSVExporter().writeToTemporaryFile(results: [result]) {
                ShareSheet(items: [url])
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 6) {
            Text("\(result.earnedPoints, specifier: "%.1f") / \(result.totalPoints, specifier: "%.0f")")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("\(result.percentage, specifier: "%.1f")%")
                .font(.title3)
                .foregroundStyle(.secondary)
            if result.ambiguousCount > 0 {
                Label("\(result.ambiguousCount) إجابة تحتاج مراجعة يدوية", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top)
    }

    private var studentInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField(title: "الاسم", text: $result.studentName)
            labeledField(title: "الرقم الجامعي", text: $result.studentId)
        }
        .padding(.horizontal)
        .onChange(of: result.studentName) { _, _ in persist() }
        .onChange(of: result.studentId) { _, _ in persist() }
    }

    private func labeledField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var answersListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("تفصيل الإجابات").font(.headline).padding(.horizontal)
            ForEach($result.answers) { $answer in
                HStack {
                    Text("سؤال \(answer.questionNumber)")
                        .frame(width: 80, alignment: .leading)
                    Text(answer.detectedLabel ?? "—")
                        .font(.body.weight(.semibold))
                    Spacer()
                    statusBadge(answer)
                    Button("تصحيح يدوي") { showManualEditFor = answer.questionNumber }
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                Divider().padding(.horizontal)
            }
        }
        .confirmationDialog("اختر الإجابة الصحيحة للسؤال", isPresented: Binding(
            get: { showManualEditFor != nil }, set: { if !$0 { showManualEditFor = nil } }
        )) {
            if let qNum = showManualEditFor, let template,
               let group = template.questionGroups.first(where: { $0.questionNumber == qNum }) {
                ForEach(group.choices, id: \.id) { choice in
                    Button(choice.label) { setManualAnswer(question: qNum, label: choice.label) }
                }
                Button("فارغة (بدون إجابة)") { setManualAnswer(question: qNum, label: nil) }
                Button("إلغاء", role: .cancel) {}
            }
        }
    }

    private func statusBadge(_ answer: DetectedAnswer) -> some View {
        let (text, color): (String, Color) = {
            switch (answer.isCorrect, answer.state) {
            case (true, _): return ("صحيحة", .green)
            case (false, _): return ("خاطئة", .red)
            case (nil, .ambiguous): return ("غامضة", .orange)
            case (nil, .blank): return ("فارغة", .gray)
            default: return ("—", .secondary)
            }
        }()
        return Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func setManualAnswer(question: Int, label: String?) {
        guard let idx = result.answers.firstIndex(where: { $0.questionNumber == question }) else { return }
        result.answers[idx].detectedLabel = label
        result.answers[idx].state = label == nil ? .blank : .filled

        // إعادة تقييم صحة الإجابة بعد التعديل اليدوي مقابل مفتاح الإجابة
        if let template, let key = answerKeyStore.key(for: template.id),
           let correctLabel = key.correctAnswers[question] {
            let maxPoints = template.questionGroups.first { $0.questionNumber == question }?.points ?? 0
            let isCorrect = (label == correctLabel)
            result.answers[idx].isCorrect = isCorrect
            result.answers[idx].pointsAwarded = isCorrect ? maxPoints : 0
        }
        recomputeScore()
        persist()
        showManualEditFor = nil
    }

    private func recomputeScore() {
        // يعيد حساب المجموع بافتراض أن isCorrect الحالي محدث مسبقاً لكل سؤال
        // من عملية التصحيح الأصلية؛ التعديل اليدوي هنا يغيّر التسمية المكتشفة
        // فقط، والمراجعة النهائية للدرجة تتم عبر GradingEngine عند إعادة التصحيح.
        result.earnedPoints = result.answers.reduce(0) { $0 + $1.pointsAwarded }
    }

    private func persist() {
        try? resultsStore.save(result)
    }

    @ViewBuilder
    private func bubbleOverlay(for answer: DetectedAnswer, template: ScanTemplate, displaySize: CGSize) -> some View {
        if let group = template.questionGroups.first(where: { $0.questionNumber == answer.questionNumber }) {
            ForEach(group.choices, id: \.id) { choice in
                let point = choice.center.toPixel(in: displaySize)
                let isDetected = choice.label == answer.detectedLabel
                Circle()
                    .stroke(color(for: answer, isThisChoiceDetected: isDetected), lineWidth: isDetected ? 3 : 1)
                    .frame(width: 26, height: 26)
                    .position(x: point.x, y: point.y)
            }
        }
    }

    private func color(for answer: DetectedAnswer, isThisChoiceDetected: Bool) -> Color {
        guard isThisChoiceDetected else { return .clear }
        switch (answer.isCorrect, answer.state) {
        case (true, _): return .green
        case (false, _): return .red
        case (nil, .ambiguous): return .orange
        default: return .blue
        }
    }
}

/// غلاف بسيط لـ UIActivityViewController لمشاركة ملف CSV
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
