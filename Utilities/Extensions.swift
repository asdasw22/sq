//
//  Extensions.swift
//  SmartGradeScanner
//

import Foundation

extension Double {
    /// يقرّب النسبة المئوية لعرض أنظف بالواجهة
    var roundedPercentage: String {
        String(format: "%.1f%%", self)
    }
}

extension Array where Element == DetectedAnswer {
    var correctCount: Int { filter { $0.isCorrect == true }.count }
    var incorrectCount: Int { filter { $0.isCorrect == false }.count }
}
