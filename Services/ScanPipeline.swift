//
//  ScanPipeline.swift
//  SmartGradeScanner
//
//  المنسّق (Orchestrator) الذي يجمع كل الخدمات في تدفّق عمل واحد غير
//  متزامن (async): من صورة خام (أي صورة، أي زاوية) إلى نتيجة تصحيح
//  كاملة. هذا هو "الواجهة" التي تستدعيها الشاشات (Views) لمعالجة صورة.
//

import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

enum ScanPipelineError: Error, LocalizedError {
    case imageConversionFailed
    case alignmentFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "تعذّرت قراءة الصورة الملتقطة."
        case .alignmentFailed(let err): return err.localizedDescription
        }
    }
}

struct ScanPipelineResult {
    var gradeResult: GradeResult
    var alignedImage: CGImage
}

final class ScanPipeline {

    private let aligner = DocumentAligner()
    private let bubbleDetector = BubbleDetector()
    private let ocrService = OCRService()
    private let gradingEngine = GradingEngine()

    /// ينفّذ خط الأنابيب الكامل على صورة واحدة. يعمل بشكل غير متزامن
    /// لأن اكتشاف المستطيلات وOCR عمليات قد تستغرق وقتاً على صور كبيرة.
    func process(
        cgImage: CGImage,
        template: ScanTemplate,
        answerKey: AnswerKey?,
        saveAlignedImageTo directory: URL? = nil
    ) async throws -> ScanPipelineResult {

        // 1) محاذاة الصورة (تعمل مع أي صورة تحتوي الورقة، أي زاوية/إضاءة)
        let aligned: CGImage
        do {
            aligned = try aligner.align(cgImage: cgImage, targetSize: template.referenceSize.cgSize)
        } catch {
            throw ScanPipelineError.alignmentFailed(error)
        }

        // 2) كشف الفقاعات المملوءة لكل سؤال
        let detected = bubbleDetector.detectAnswers(in: aligned, template: template)

        // 3) قراءة الحقول النصية (اسم/رقم) عبر OCR
        let fields = ocrService.recognizeFields(in: aligned, template: template)

        // 4) حفظ الصورة المصححة اختيارياً (للمراجعة اليدوية لاحقاً)
        var savedPath: String?
        if let directory {
            savedPath = try? saveImage(aligned, in: directory)
        }

        // 5) التصحيح وحساب الدرجة
        let result = gradingEngine.grade(
            detectedAnswers: detected,
            studentFields: fields,
            template: template,
            answerKey: answerKey,
            correctedImagePath: savedPath
        )

        return ScanPipelineResult(gradeResult: result, alignedImage: aligned)
    }

    private func saveImage(_ image: CGImage, in directory: URL) throws -> String {
        let filename = "\(UUID().uuidString).png"
        let url = directory.appendingPathComponent(filename)
        #if canImport(UIKit)
        let uiImage = UIImage(cgImage: image)
        guard let data = uiImage.pngData() else { throw ScanPipelineError.imageConversionFailed }
        try data.write(to: url, options: .atomic)
        #endif
        return filename
    }
}
