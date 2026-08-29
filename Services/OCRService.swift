//
//  OCRService.swift
//  SmartGradeScanner
//
//  يقرأ الحقول النصية المعرّفة في التمبليت (مثل اسم الطالب والرقم
//  الجامعي) من الصورة المُحاذاة، عبر اقتصاص منطقة كل حقل ثم تمريرها
//  لـ Vision Text Recognition (VNRecognizeTextRequest).
//

import Foundation
import Vision
import CoreGraphics

struct OCRService {

    /// يقرأ كل الحقول النصية المعرّفة في التمبليت من صورة مُحاذاة، ويُرجع
    /// قاموساً [key: القيمة المقروءة]
    func recognizeFields(in alignedImage: CGImage, template: ScanTemplate,
                          recognitionLanguages: [String] = ["ar", "en"]) -> [String: String] {
        var results: [String: String] = [:]
        let size = CGSize(width: alignedImage.width, height: alignedImage.height)

        for field in template.studentInfoFields {
            let pixelRect = field.rect.toPixelRect(in: size)
            guard let cropped = crop(image: alignedImage, to: pixelRect, imageHeight: size.height) else {
                results[field.key] = ""
                continue
            }
            let text = recognizeText(in: cropped, languages: recognitionLanguages)
            results[field.key] = text
        }
        return results
    }

    private func crop(image: CGImage, to rect: CGRect, imageHeight: CGFloat) -> CGImage? {
        // نظام إحداثيات CGImage.cropping هو أعلى-يسار مثل التمبليت، فلا حاجة لعكس y هنا
        // (بخلاف CoreImage الذي يستخدم أسفل-يسار).
        let padded = rect.insetBy(dx: -4, dy: -4)
        let clamped = padded.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard clamped.width > 1, clamped.height > 1 else { return nil }
        return image.cropping(to: clamped)
    }

    private func recognizeText(in image: CGImage, languages: [String]) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        guard let observations = request.results else { return "" }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
