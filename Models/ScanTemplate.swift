//
//  ScanTemplate.swift
//  SmartGradeScanner
//
//  يمثّل هذا الملف "قلب" فكرة المشروع: تمبليت (نموذج) قابل لإعادة الاستخدام
//  يصف مكان كل فقاعة إجابة وكل حقل نصي (اسم / رقم جامعي) بإحداثيات
//  منسّبة (Normalized 0...1) بالنسبة لحجم الورقة المرجعي، بدل إحداثيات
//  بكسل ثابتة. هذا يعني أن نفس التمبليت يعمل على أي صورة ملتقطة بأي
//  دقة أو زاوية، طالما تمت محاذاتها (Alignment) أولاً عبر DocumentAligner.
//
//  لإنشاء تمبليت جديد لورقة مختلفة عن غيرها: إمّا استخدام TemplateEditorView
//  داخل التطبيق (رسم تفاعلي)، أو توليد ملف JSON بنفس البنية (كما يفعل
//  السكربت generate_template.py المرفق في Resources/Templates).
//

import Foundation
import CoreGraphics

// MARK: - نقطة/مستطيل منسّبان (0...1)

struct NormalizedPoint: Codable, Hashable {
    var x: Double
    var y: Double

    /// يحوّل النقطة المنسّبة إلى نقطة بكسل حقيقية بالنسبة لحجم صورة معيّن
    func toPixel(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    static func fromPixel(_ point: CGPoint, in size: CGSize) -> NormalizedPoint {
        NormalizedPoint(x: point.x / size.width, y: point.y / size.height)
    }
}

struct NormalizedRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func toPixelRect(in size: CGSize) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height,
               width: width * size.width, height: height * size.height)
    }

    static func fromPixelRect(_ rect: CGRect, in size: CGSize) -> NormalizedRect {
        NormalizedRect(x: rect.origin.x / size.width,
                        y: rect.origin.y / size.height,
                        width: rect.width / size.width,
                        height: rect.height / size.height)
    }
}

// MARK: - حقل نصي (اسم الطالب، الرقم الجامعي، أي حقل يُقرأ بالـ OCR)

struct TextFieldRegion: Codable, Identifiable, Hashable {
    var id: UUID
    var key: String          // معرف برمجي ثابت: "studentName", "studentId"...
    var displayName: String  // الاسم المعروض للمستخدم
    var rect: NormalizedRect
}

// MARK: - خيار إجابة واحد (فقاعة واحدة ضمن سؤال)

struct AnswerChoice: Codable, Identifiable, Hashable {
    var id: UUID
    var label: String   // "A", "B", "C"... أو "1","2" لأسئلة صح/خطأ إلخ
    var center: NormalizedPoint
}

// MARK: - مجموعة خيارات سؤال واحد

struct QuestionGroup: Codable, Identifiable, Hashable {
    var id: UUID
    var questionNumber: Int
    var points: Double
    var choices: [AnswerChoice]
}

// MARK: - حجم مرجعي بالبكسل (الحجم الذي صُمم عليه التمبليت)

struct ReferenceSize: Codable, Hashable {
    var width: Double
    var height: Double

    var cgSize: CGSize { CGSize(width: width, height: height) }
}

// MARK: - التمبليت الكامل

struct ScanTemplate: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date

    /// الحجم الذي رُسم عليه التمبليت الأصلي (يُستخدم فقط لأغراض العرض/التحرير،
    /// كل الإحداثيات الفعلية منسّبة وتعمل بأي حجم).
    var referenceSize: ReferenceSize

    /// الإطار الخارجي للورقة (يُستخدم لمحاذاة الصورة الملتقطة عبر
    /// اكتشاف المستطيل الأكبر بالصورة - VNDetectRectanglesRequest)
    var alignmentFrame: NormalizedRect

    /// نقاط أركان إضافية (مربعات سوداء) يمكن استخدامها لتحسين دقة المحاذاة
    var cornerMarkers: [String: NormalizedPoint]

    /// الحقول النصية التي تُقرأ عبر Vision OCR
    var studentInfoFields: [TextFieldRegion]

    /// قطر الفقاعة الواحدة (منسّب) - يُستخدم لتحديد منطقة أخذ العيّنة
    var bubbleDiameter: Double

    /// نسبة الاسوداد (0...1) التي فوقها تُعتبر الفقاعة "مملوءة"
    var fillThreshold: Double

    /// كل الأسئلة وخياراتها
    var questionGroups: [QuestionGroup]

    var totalPoints: Double {
        questionGroups.reduce(0) { $0 + $1.points }
    }
}

// MARK: - تحميل التمبليتات المرفقة مسبقاً مع التطبيق (Bundle Resources)

extension ScanTemplate {
    /// يقرأ تمبليت من ملف JSON داخل الحزمة (Bundle) - مثال:
    /// ScanTemplate.loadBundled(named: "bubble_sheet_20q")
    static func loadBundled(named name: String) -> ScanTemplate? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json",
                                         subdirectory: "Templates") ??
                         Bundle.main.url(forResource: name, withExtension: "json")
        else { return nil }
        return try? load(from: url)
    }

    static func load(from url: URL) throws -> ScanTemplate {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScanTemplate.self, from: data)
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - إنشاء تمبليت شبكي تلقائياً (يُستخدم من TemplateEditorView)

extension ScanTemplate {
    /// يبني تمبليت جديد بالكامل برمجياً: عدد أسئلة × عدد خيارات، موزّعة
    /// على أعمدة، بالإضافة لحقلي اسم ورقم. هذا ما يسمح للمستخدم بإنشاء
    /// تمبليت لأي ورقة إجابة جديدة (مختلفة عن الجاهزة) خلال ثوانٍ من
    /// داخل التطبيق نفسه، بدل الاعتماد فقط على الـ JSON المُرفق.
    static func generateGrid(
        name: String,
        questionCount: Int,
        choiceLabels: [String] = ["A", "B", "C", "D"],
        columns: Int = 2,
        pointsPerQuestion: Double = 1.0,
        includeNameField: Bool = true,
        includeIdField: Bool = true
    ) -> ScanTemplate {
        let width = 1240.0
        let height = 1754.0
        let margin = 60.0
        let frameInset = 40.0

        var groups: [QuestionGroup] = []
        let rowsPerColumn = Int(ceil(Double(questionCount) / Double(columns)))
        let colWidth = (width - 2 * margin) / Double(columns)
        let rowHeight = 62.0
        let gridTop = 330.0
        let bubbleGap = 46.0

        var q = 1
        for col in 0..<columns {
            let colX0 = margin + Double(col) * colWidth + 85
            for row in 0..<rowsPerColumn where q <= questionCount {
                let qy = gridTop + Double(row) * rowHeight
                var choices: [AnswerChoice] = []
                for (i, label) in choiceLabels.enumerated() {
                    let cx = colX0 + Double(i) * bubbleGap
                    choices.append(AnswerChoice(
                        id: UUID(), label: label,
                        center: NormalizedPoint(x: cx / width, y: qy / height)
                    ))
                }
                groups.append(QuestionGroup(id: UUID(), questionNumber: q,
                                             points: pointsPerQuestion, choices: choices))
                q += 1
            }
        }

        var fields: [TextFieldRegion] = []
        if includeNameField {
            fields.append(TextFieldRegion(
                id: UUID(), key: "studentName", displayName: "Name",
                rect: NormalizedRect(x: (margin + 190) / width, y: 130 / height,
                                      width: (width - margin - 20 - (margin + 190)) / width,
                                      height: 40 / height)))
        }
        if includeIdField {
            fields.append(TextFieldRegion(
                id: UUID(), key: "studentId", displayName: "ID",
                rect: NormalizedRect(x: (margin + 230) / width, y: 190 / height,
                                      width: 380 / width, height: 40 / height)))
        }

        return ScanTemplate(
            id: UUID(),
            name: name,
            createdAt: Date(),
            referenceSize: ReferenceSize(width: width, height: height),
            alignmentFrame: NormalizedRect(x: frameInset / width, y: frameInset / height,
                                            width: (width - 2 * frameInset) / width,
                                            height: (height - 2 * frameInset) / height),
            cornerMarkers: [
                "topLeft": NormalizedPoint(x: (frameInset + 20) / width, y: (frameInset + 20) / height),
                "topRight": NormalizedPoint(x: (width - frameInset - 20) / width, y: (frameInset + 20) / height),
                "bottomLeft": NormalizedPoint(x: (frameInset + 20) / width, y: (height - frameInset - 20) / height),
                "bottomRight": NormalizedPoint(x: (width - frameInset - 20) / width, y: (height - frameInset - 20) / height),
            ],
            studentInfoFields: fields,
            bubbleDiameter: 26 / ((width + height) / 2),
            fillThreshold: 0.45,
            questionGroups: groups
        )
    }
}
