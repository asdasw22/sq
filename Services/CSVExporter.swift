//
//  CSVExporter.swift
//  SmartGradeScanner
//

import Foundation

struct CSVExporter {

    /// يبني ملف CSV يحتوي: اسم الطالب، الرقم، الدرجة، النسبة، عدد
    /// الفقاعات الغامضة، وتفصيل كل سؤال. مناسب للاستيراد المباشر إلى
    /// Excel أو Google Sheets من قبل المدرّس.
    func export(results: [GradeResult]) -> String {
        guard let first = results.first else { return "" }

        let questionNumbers = first.answers.map(\.questionNumber).sorted()
        var header = ["StudentName", "StudentID", "Score", "Total", "Percentage", "NeedsReview"]
        header += questionNumbers.map { "Q\($0)" }

        var lines: [String] = [header.joined(separator: ",")]

        for result in results {
            var row: [String] = [
                escape(result.studentName),
                escape(result.studentId),
                String(format: "%.2f", result.earnedPoints),
                String(format: "%.2f", result.totalPoints),
                String(format: "%.1f%%", result.percentage),
                result.ambiguousCount > 0 ? "YES" : "NO",
            ]
            let byQuestion = Dictionary(uniqueKeysWithValues: result.answers.map { ($0.questionNumber, $0) })
            for q in questionNumbers {
                row.append(byQuestion[q]?.detectedLabel ?? "-")
            }
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    func writeToTemporaryFile(results: [GradeResult], filename: String = "grades_export.csv") -> URL? {
        let csv = export(results: results)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
