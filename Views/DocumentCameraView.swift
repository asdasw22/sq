//
//  DocumentCameraView.swift
//  SmartGradeScanner
//
//  غلاف SwiftUI حول VNDocumentCameraViewController (من VisionKit) -
//  وهو ماسح المستندات المدمج في iOS نفسه (يستخدمه تطبيق "الملاحظات").
//  يعطينا صورة عالية الجودة بحواف شبه مقصوصة تلقائياً، ثم نمرّرها
//  لخط الأنابيب (ScanPipeline) الذي يقوم بمحاذاة دقيقة إضافية.
//

import SwiftUI
import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        init(_ parent: DocumentCameraView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                           didFinishWith scan: VNDocumentCameraScan) {
            // نأخذ أول صفحة ممسوحة فقط (ورقة إجابة واحدة لكل مسحة).
            // يمكن بسهولة توسيع هذا لدعم مسح دفعة كاملة من الأوراق دفعة
            // واحدة عبر تكرار for i in 0..<scan.pageCount.
            if scan.pageCount > 0 {
                parent.onCapture(scan.imageOfPage(at: 0))
            } else {
                parent.onCancel()
            }
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                           didFailWithError error: Error) {
            parent.onCancel()
            controller.dismiss(animated: true)
        }
    }
}

/// بديل: اختيار صورة موجودة مسبقاً من مكتبة الصور (لأي صورة التقطها
/// المستخدم سابقاً بأي كاميرا، بما يخدم فكرة "التمبليت يتعامل مع أي صورة")
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            } else {
                parent.onCancel()
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
            picker.dismiss(animated: true)
        }
    }
}
