//
//  ScanHomeView.swift
//  SmartGradeScanner
//

import SwiftUI

struct ScanHomeView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @EnvironmentObject private var resultsStore: ResultsStore
    @EnvironmentObject private var answerKeyStore: AnswerKeyStore

    @State private var selectedTemplate: ScanTemplate?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var pipelineResult: ScanPipelineResult?
    @State private var navigateToResult = false

    private let pipeline = ScanPipeline()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                templatePicker

                VStack(spacing: 14) {
                    actionButton(title: "مسح ضوئي بالكاميرا", icon: "camera.fill") {
                        showCamera = true
                    }
                    actionButton(title: "اختيار صورة من المعرض", icon: "photo.on.rectangle") {
                        showPhotoPicker = true
                    }
                }
                .disabled(selectedTemplate == nil || isProcessing)
                .opacity(selectedTemplate == nil ? 0.5 : 1)

                if isProcessing {
                    ProgressView("جاري تحليل الورقة...")
                        .padding(.top, 8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("SmartGradeScanner")
            .onAppear {
                if selectedTemplate == nil { selectedTemplate = templateStore.templates.first }
            }
            .sheet(isPresented: $showCamera) {
                DocumentCameraView(
                    onCapture: { image in handleCaptured(image) },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoLibraryPicker(
                    onPick: { image in handleCaptured(image) },
                    onCancel: { showPhotoPicker = false }
                )
                .ignoresSafeArea()
            }
            .navigationDestination(isPresented: $navigateToResult) {
                if let pipelineResult {
                    ResultsView(result: pipelineResult.gradeResult, alignedImage: pipelineResult.alignedImage)
                }
            }
        }
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("اختر القالب (Template)")
                .font(.headline)
            Menu {
                ForEach(templateStore.templates) { template in
                    Button(template.name) { selectedTemplate = template }
                }
            } label: {
                HStack {
                    Text(selectedTemplate?.name ?? "لا يوجد قوالب - أنشئ واحداً من تبويب القوالب")
                        .foregroundStyle(selectedTemplate == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
            if let selectedTemplate {
                Text("\(selectedTemplate.questionGroups.count) سؤال · \(Int(selectedTemplate.totalPoints)) نقطة")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .font(.body.weight(.semibold))
            .padding()
            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func handleCaptured(_ image: UIImage) {
        showCamera = false
        showPhotoPicker = false
        guard let template = selectedTemplate, let cgImage = image.cgImage else {
            errorMessage = "تعذّرت قراءة الصورة."
            return
        }
        errorMessage = nil
        isProcessing = true

        let key = answerKeyStore.key(for: template.id)

        Task {
            do {
                let result = try await pipeline.process(
                    cgImage: cgImage,
                    template: template,
                    answerKey: key,
                    saveAlignedImageTo: AppDirectories.scannedImagesDirectory
                )
                try? resultsStore.save(result.gradeResult)
                await MainActor.run {
                    self.pipelineResult = result
                    self.isProcessing = false
                    self.navigateToResult = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ScanHomeView()
        .environmentObject(TemplateStore())
        .environmentObject(ResultsStore())
        .environmentObject(AnswerKeyStore())
}
