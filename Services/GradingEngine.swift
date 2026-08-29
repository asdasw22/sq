//
//  GradingEngine.swift
//  SmartGradeScanner
//

import Foundation

struct GradingEngine {

    /// يقارن الإجابات المكتشفة بمفتاح الإجابة (إن وُجد)، ويملأ isCorrect
    /// وpointsAwarded لكل سؤال، ثم يبني GradeResult كاملاً.
    func grade(
        detectedAnswers: [DetectedAnswer],
        studentFields: [String: String],
        template: ScanTemplate,
        answerKey: AnswerKey?,
        correctedImagePath: String?
    ) -> GradeResult {

        var graded: [DetectedAnswer] = []
        var earned: Double = 0

        let pointsByQuestion = Dictionary(uniqueKeysWithValues:
            template.questionGroups.map { ($0.questionNumber, $0.points) })

        for var answer in detectedAnswers {
            let maxPoints = pointsByQuestion[answer.questionNumber] ?? 0

            if let key = answerKey, let correctLabel = key.correctAnswers[answer.questionNumber] {
                let isCorrect = (answer.detectedLabel == correctLabel) && answer.state == .filled
                answer.isCorrect = isCorrect
                answer.pointsAwarded = isCorrect ? maxPoints : 0
                earned += answer.pointsAwarded
            } else {
                answer.isCorrect = nil
                answer.pointsAwarded = 0
            }
            graded.append(answer)
        }

        return GradeResult(
            templateId: template.id,
            templateName: template.name,
            studentName: studentFields["studentName"] ?? "",
            studentId: studentFields["studentId"] ?? "",
            answers: graded.sorted { $0.questionNumber < $1.questionNumber },
            totalPoints: template.totalPoints,
            earnedPoints: earned,
            correctedImagePath: correctedImagePath
        )
    }
}
