//
//  BubbleDetector.swift
//  SmartGradeScanner
//
//  يأخذ صورة مُحاذاة (مخرجات DocumentAligner) وتمبليت، ولكل سؤال يقيس
//  درجة الاسوداد (Darkness) داخل كل فقاعة عبر أخذ متوسط الإضاءة في
//  منطقة دائرية صغيرة حول مركز الفقاعة (CIAreaAverage)، ثم يقارنها
//  بعتبة (fillThreshold) وبباقي الخيارات لتحديد: مملوءة / فارغة / غامضة.
//

import Foundation
import CoreImage
import CoreGraphics

struct BubbleDetector {

    private let context = CIContext()

    /// يحلّل كل أسئلة التمبليت على الصورة المُحاذاة، ويُرجع نتيجة لكل سؤال
    func detectAnswers(in alignedImage: CGImage, template: ScanTemplate) -> [DetectedAnswer] {
        let ciImage = CIImage(cgImage: alignedImage)
        let size = CGSize(width: alignedImage.width, height: alignedImage.height)
        let bubbleRadiusPx = (template.bubbleDiameter * ((size.width + size.height) / 2)) / 2
        // نأخذ عيّنة من منتصف الفقاعة بنصف قطر أصغر قليلاً من الرسم، لتفادي
        // التقاط حدود الدائرة نفسها (التي تكون سوداء دائماً كخط رسم)
        let sampleRadius = max(4, bubbleRadiusPx * 0.6)

        var results: [DetectedAnswer] = []

        for group in template.questionGroups.sorted(by: { $0.questionNumber < $1.questionNumber }) {
            var darkness: [String: Double] = [:]

            for choice in group.choices {
                let centerPx = choice.center.toPixel(in: size)
                let darknessValue = averageDarkness(
                    in: ciImage,
                    center: centerPx,
                    radius: sampleRadius,
                    imageHeight: size.height
                )
                darkness[choice.label] = darknessValue
            }

            let sortedByDarkness = darkness.sorted { $0.value > $1.value }
            let filled = sortedByDarkness.filter { $0.value >= template.fillThreshold }

            let answer: DetectedAnswer
            if filled.isEmpty {
                answer = DetectedAnswer(questionNumber: group.questionNumber,
                                         detectedLabel: nil, state: .blank,
                                         choiceDarkness: darkness)
            } else if filled.count == 1 {
                answer = DetectedAnswer(questionNumber: group.questionNumber,
                                         detectedLabel: filled[0].key, state: .filled,
                                         choiceDarkness: darkness)
            } else {
                // أكثر من فقاعة "مملوءة" بنفس السؤال: إن كان الفارق بين
                // الأعلى والثاني كبيراً بما يكفي، نعتبرها إجابة واحدة واضحة
                let gap = filled[0].value - filled[1].value
                if gap > 0.18 {
                    answer = DetectedAnswer(questionNumber: group.questionNumber,
                                             detectedLabel: filled[0].key, state: .filled,
                                             choiceDarkness: darkness)
                } else {
                    answer = DetectedAnswer(questionNumber: group.questionNumber,
                                             detectedLabel: nil, state: .ambiguous,
                                             choiceDarkness: darkness)
                }
            }
            results.append(answer)
        }

        return results
    }

    /// يحسب متوسط الاسوداد (0 = أبيض تماماً، 1 = أسود تماماً) داخل دائرة
    /// صغيرة حول نقطة معيّنة، باستخدام CIAreaAverage.
    private func averageDarkness(in image: CIImage, center: CGPoint, radius: CGFloat, imageHeight: CGFloat) -> Double {
        // CoreImage يستخدم إحداثيات (0,0) أسفل-يسار، بينما مصدرنا (التمبليت)
        // مبني بنظام (0,0) أعلى-يسار (كالشاشات المعتادة)، لذلك نعكس y.
        let flippedY = imageHeight - center.y

        let rect = CGRect(x: center.x - radius, y: flippedY - radius,
                           width: radius * 2, height: radius * 2)

        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0 }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: rect), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                        toBitmap: &bitmap,
                        rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8,
                        colorSpace: CGColorSpaceCreateDeviceRGB())

        // متوسط قنوات RGB → درجة الرمادي، ثم نحوّلها لدرجة "اسوداد" (معكوسة)
        let gray = (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / 3.0 / 255.0
        return 1.0 - gray
    }
}
