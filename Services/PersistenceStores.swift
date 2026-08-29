//
//  PersistenceStores.swift
//  SmartGradeScanner
//
//  تخزين بسيط قائم على ملفات JSON داخل مجلد Documents الخاص بالتطبيق.
//  كافٍ تماماً لحجم بيانات هذا التطبيق (عدد تمبليتات محدود، ونتائج
//  مسح تُعد بالمئات/الآلاف)، ويُغني عن تعقيد Core Data لهذا النطاق.
//  يمكن استبداله لاحقاً بسهولة بـ Core Data أو SwiftData دون تغيير
//  واجهات الاستخدام في الشاشات (Views) لأن كل شيء يمر عبر بروتوكولات.
//

import Foundation

// MARK: - مجلدات التطبيق

enum AppDirectories {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    static var templatesDirectory: URL {
        let url = documents.appendingPathComponent("Templates", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var resultsDirectory: URL {
        let url = documents.appendingPathComponent("Results", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var scannedImagesDirectory: URL {
        let url = documents.appendingPathComponent("ScannedImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var answerKeysDirectory: URL {
        let url = documents.appendingPathComponent("AnswerKeys", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

// MARK: - TemplateStore

@MainActor
final class TemplateStore: ObservableObject {
    @Published private(set) var templates: [ScanTemplate] = []

    init() {
        loadAll()
        if templates.isEmpty {
            seedBundledTemplatesIfNeeded()
        }
    }

    func loadAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: AppDirectories.templatesDirectory,
                                                        includingPropertiesForKeys: nil) else { return }
        templates = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? ScanTemplate.load(from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ template: ScanTemplate) throws {
        let url = AppDirectories.templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        try template.save(to: url)
        loadAll()
    }

    func delete(_ template: ScanTemplate) throws {
        let url = AppDirectories.templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        try FileManager.default.removeItem(at: url)
        loadAll()
    }

    /// عند أول تشغيل: ينسخ التمبليت الجاهز (bubble_sheet_20q) من حزمة
    /// التطبيق إلى تخزين المستخدم، ليكون جاهزاً للاستخدام فوراً وقابلاً
    /// للتعديل. هذا هو "التمبليت الجاهز" المطلوب - نقطة انطلاق فقط،
    /// وليس قيداً: المستخدم يقدر يبني تمبليتات أخرى بالكامل من الصفر.
    private func seedBundledTemplatesIfNeeded() {
        if let bundled = ScanTemplate.loadBundled(named: "bubble_sheet_20q") {
            try? save(bundled)
        } else {
            // fallback: يولّد نفس التمبليت برمجياً إن لم يوجد ملف الحزمة بعد
            let generated = ScanTemplate.generateGrid(name: "ورقة إجابة - 20 سؤال (A-D)", questionCount: 20)
            try? save(generated)
        }
    }
}

// MARK: - ResultsStore

@MainActor
final class ResultsStore: ObservableObject {
    @Published private(set) var results: [GradeResult] = []

    init() {
        loadAll()
    }

    func loadAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: AppDirectories.resultsDirectory,
                                                        includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        results = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> GradeResult? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(GradeResult.self, from: data)
            }
            .sorted { $0.scannedAt > $1.scannedAt }
    }

    func save(_ result: GradeResult) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        let url = AppDirectories.resultsDirectory.appendingPathComponent("\(result.id.uuidString).json")
        try data.write(to: url, options: .atomic)
        loadAll()
    }

    func delete(_ result: GradeResult) throws {
        let url = AppDirectories.resultsDirectory.appendingPathComponent("\(result.id.uuidString).json")
        try FileManager.default.removeItem(at: url)
        if let imagePath = result.correctedImagePath {
            try? FileManager.default.removeItem(
                at: AppDirectories.scannedImagesDirectory.appendingPathComponent(imagePath))
        }
        loadAll()
    }

    func results(for templateId: UUID) -> [GradeResult] {
        results.filter { $0.templateId == templateId }
    }
}

// MARK: - AnswerKeyStore

@MainActor
final class AnswerKeyStore: ObservableObject {
    @Published private(set) var keys: [AnswerKey] = []

    init() { loadAll() }

    func loadAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: AppDirectories.answerKeysDirectory,
                                                        includingPropertiesForKeys: nil) else { return }
        keys = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> AnswerKey? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(AnswerKey.self, from: data)
            }
    }

    func save(_ key: AnswerKey) throws {
        let data = try JSONEncoder().encode(key)
        let url = AppDirectories.answerKeysDirectory.appendingPathComponent("\(key.id.uuidString).json")
        try data.write(to: url, options: .atomic)
        loadAll()
    }

    func delete(_ key: AnswerKey) throws {
        let url = AppDirectories.answerKeysDirectory.appendingPathComponent("\(key.id.uuidString).json")
        try FileManager.default.removeItem(at: url)
        loadAll()
    }

    func key(for templateId: UUID) -> AnswerKey? {
        keys.first { $0.templateId == templateId }
    }
}
