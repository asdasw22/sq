//
//  SmartGradeScannerApp.swift
//  SmartGradeScanner
//
//  للتشغيل: أنشئ مشروع iOS App جديد في Xcode (SwiftUI, iOS 16+)،
//  ثم اسحب كل الملفات ضمن مجلد SmartGradeScanner (App/Models/Services/
//  Views/Utilities/Resources) إلى المشروع، وتأكد من إضافة مجلد
//  Resources/Templates كـ "Folder Reference" (أزرق) حتى تُقرأ ملفات
//  JSON عبر Bundle.main في وقت التشغيل.
//
//  الأذونات المطلوبة في Info.plist:
//   - NSCameraUsageDescription  (لاستخدام الكاميرا لمسح الأوراق)
//   - NSPhotoLibraryUsageDescription (لاختيار صورة من المعرض)
//

import SwiftUI

@main
struct SmartGradeScannerApp: App {
    @StateObject private var templateStore = TemplateStore()
    @StateObject private var resultsStore = ResultsStore()
    @StateObject private var answerKeyStore = AnswerKeyStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(templateStore)
                .environmentObject(resultsStore)
                .environmentObject(answerKeyStore)
        }
    }
}
