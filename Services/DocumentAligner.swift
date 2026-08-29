//
//  DocumentAligner.swift
//  SmartGradeScanner
//
//  هذه هي الخطوة التي تجعل التمبليت "يتعامل مع أي صورة": بدل الاعتماد
//  على أن تكون الصورة الملتقطة مسطّحة ومقصوصة تماماً على حواف الورقة،
//  نستخدم Vision لاكتشاف أكبر مستطيل (شبه منحرف) داخل الصورة (حواف
//  الورقة)، ثم نستخدم CoreImage (CIPerspectiveCorrection) لتسوية
//  الصورة إلى مستطيل تام يطابق الحجم المرجعي referenceSize للتمبليت.
//  بعد هذه الخطوة، أي إحداثي منسّب (0...1) داخل التمبليت يشير مباشرة
//  إلى نفس الموضع الصحيح على الصورة المصححة - بغض النظر عن زاوية أو
//  دقة أو إضاءة الصورة الأصلية.
//

import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

enum DocumentAlignerError: Error, LocalizedError {
    case noRectangleDetected
    case correctionFailed
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .noRectangleDetected: return "لم يتم العثور على حواف ورقة واضحة في الصورة. حاول تصوير الورقة كاملة على خلفية متباينة وبإضاءة جيدة."
        case .correctionFailed: return "تعذّر تصحيح زاوية التصوير (Perspective Correction)."
        case .invalidImage: return "الصورة المُدخلة غير صالحة."
        }
    }
}

final class DocumentAligner {

    private let context = CIContext()

    /// يحاذي صورة ملتقطة (أي زاوية/إضاءة) إلى مستطيل مسطّح بحجم `targetSize`
    /// (عادة referenceSize الخاص بالتمبليت)، مستعداً كي تُطبَّق عليه
    /// إحداثيات التمبليت المنسّبة مباشرة.
    func align(cgImage: CGImage, targetSize: CGSize,
               minimumConfidence: Float = 0.6) throws -> CGImage {

        let ciImage = CIImage(cgImage: cgImage)

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.4          // الورقة يجب أن تشغل جزءاً كبيراً من الصورة
        request.minimumConfidence = minimumConfidence
        request.maximumObservations = 3
        request.quadratureTolerance = 30

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw DocumentAlignerError.noRectangleDetected
        }

        // نختار أكبر مستطيل مكتشَف (الأرجح أنه حدود الورقة نفسها)
        let best = observations.max { areaOf($0, in: cgImage) < areaOf($1, in: cgImage) }!

        // Vision يُرجع الإحداثيات بنظام (0,0) أسفل-يسار وبمقياس منسّب،
        // بينما CoreImage يتوقع إحداثيات بكسل بنفس نظام (أسفل-يسار).
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let topLeft = CGPoint(x: best.topLeft.x * w, y: best.topLeft.y * h)
        let topRight = CGPoint(x: best.topRight.x * w, y: best.topRight.y * h)
        let bottomLeft = CGPoint(x: best.bottomLeft.x * w, y: best.bottomLeft.y * h)
        let bottomRight = CGPoint(x: best.bottomRight.x * w, y: best.bottomRight.y * h)

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw DocumentAlignerError.correctionFailed
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let corrected = filter.outputImage else {
            throw DocumentAlignerError.correctionFailed
        }

        // إعادة تحجيم الصورة المصححة إلى الحجم المرجعي بالضبط، لضمان
        // تطابق الإحداثيات المنسّبة تماماً بغض النظر عن دقة التقاط الكاميرا.
        let scaleX = targetSize.width / corrected.extent.width
        let scaleY = targetSize.height / corrected.extent.height
        let scaled = corrected.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let outputCG = context.createCGImage(scaled, from: CGRect(origin: .zero, size: targetSize)) else {
            throw DocumentAlignerError.correctionFailed
        }
        return outputCG
    }

    private func areaOf(_ obs: VNRectangleObservation, in image: CGImage) -> CGFloat {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let pts = [obs.topLeft, obs.topRight, obs.bottomRight, obs.bottomLeft].map {
            CGPoint(x: $0.x * w, y: $0.y * h)
        }
        // Shoelace formula لحساب مساحة الشكل الرباعي
        var area: CGFloat = 0
        for i in 0..<pts.count {
            let p1 = pts[i]
            let p2 = pts[(i + 1) % pts.count]
            area += (p1.x * p2.y - p2.x * p1.y)
        }
        return abs(area) / 2
    }
}
