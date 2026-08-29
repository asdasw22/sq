//
//  GradeResult.swift
//  SmartGradeScanner
//

import Foundation
import CoreGraphics

/// مفتاح الإجابات الصحيحة لكل سؤال، يُستخدم من GradingEngine للمقارنة
struct AnswerKey: Codable, Identifiable, Hashable {
    var id: UUID
    var templateId: UUID
    var name: String
    /// [رقم السؤال: التسمية الصحيحة]  مثال: [1: "B", 2: "D", ...]
    var correctAnswers: [Int: String]

    enum CodingKeys: String, CodingKey {
        case id, templateId, name, correctAnswers
    }

    // Dictionary<Int, String> لا يُشفَّر مباشرة بسهولة عبر JSON (المفاتيح ليست نصوصاً
    // بشكل مباشر في كل الحالات) لذلك نوفر ترميزاً يدوياً آمناً كسلاسل نصية.
    init(id: UUID, templateId: UUID, name: String, correctAnswers: [Int: String]) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.correctAnswers = correctAnswers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        templateId = try c.decode(UUID.self, forKey: .templateId)
        name = try c.decode(String.self, forKey: .name)
        let raw = try c.decode([String: String].self, forKey: .correctAnswers)
        var dict: [Int: String] = [:]
        for (k, v) in raw { if let i = Int(k) { dict[i] = v } }
        correctAnswers = dict
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(templateId, forKey: .templateId)
        try c.encode(name, forKey: .name)
        var raw: [String: String] = [:]
        for (k, v) in correctAnswers { raw[String(k)] = v }
        try c.encode(raw, forKey: .correctAnswers)
    }
}

/// حالة فقاعة واحدة بعد التحليل
enum BubbleState: String, Codable {
    case filled          // مملوءة بوضوح
    case blank           // فارغة
    case ambiguous        // أكثر من فقاعة مملوءة بنفس السؤال (يحتاج مراجعة يدوية)
}

/// نتيجة تحليل سؤال واحد بعد المسح
struct DetectedAnswer: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var questionNumber: Int
    var detectedLabel: String?     // nil يعني لم تُكتشف أي إجابة
    var state: BubbleState
    /// درجة الثقة/الاسوداد لكل خيار (للتشخيص أو للمراجعة اليدوية)
    var choiceDarkness: [String: Double]
    var isCorrect: Bool?           // تُملأ بعد المقارنة مع AnswerKey (nil إن لم يوجد مفتاح)
    var pointsAwarded: Double = 0
}

/// نتيجة الطالب الكاملة لورقة واحدة ممسوحة
struct GradeResult: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var scannedAt: Date = Date()
    var templateId: UUID
    var templateName: String

    var studentName: String
    var studentId: String

    var answers: [DetectedAnswer]
    var totalPoints: Double
    var earnedPoints: Double

    /// عدد الفقاعات الغامضة (تحتاج مراجعة يدوية) - كلما زاد الرقم، كلما
    /// كان الأفضل مراجعة الصورة الأصلية يدوياً قبل اعتماد الدرجة
    var ambiguousCount: Int {
        answers.filter { $0.state == .ambiguous }.count
    }
    var blankCount: Int {
        answers.filter { $0.state == .blank }.count
    }

    var percentage: Double {
        guard totalPoints > 0 else { return 0 }
        return (earnedPoints / totalPoints) * 100
    }

    /// مسار الصورة المصححة (بعد المحاذاة) المخزّنة على القرص، للمراجعة لاحقاً
    var correctedImagePath: String?
}
