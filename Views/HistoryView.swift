//
//  HistoryView.swift
//  SmartGradeScanner
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var resultsStore: ResultsStore
    @EnvironmentObject private var templateStore: TemplateStore
    
    @State private var searchText = ""
    @State private var showExportAll = false

    private var filteredResults: [GradeResult] {
        guard !searchText.isEmpty else {
            return resultsStore.results
        }
        
        return resultsStore.results.filter {
            $0.studentName.localizedCaseInsensitiveContains(searchText) ||
            $0.studentId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredResults) { result in
                    NavigationLink {
                        HistoryDetailLoader(result: result)
                    } label: {
                        row(for: result)
                    }
                }
                .onDelete(perform: delete)
            }
            .searchable(
                text: $searchText,
                prompt: "ابحث بالاسم أو الرقم"
            )
            .navigationTitle("السجل")
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.topBarTrailing) {
                    Button {
                        showExportAll = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(resultsStore.results.isEmpty)
                }
            }
            .sheet(isPresented: $showExportAll) {
                if let url = CSVExporter().writeToTemporaryFile(
                    results: resultsStore.results,
                    filename: "all_grades.csv"
                ) {
                    ShareSheet(items: [url])
                }
            }
            .overlay {
                if resultsStore.results.isEmpty {
                    ContentUnavailableView(
                        "لا توجد نتائج مسح بعد",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("نتائج الأوراق الممسوحة ستظهر هنا")
                    )
                }
            }
        }
    }

    private func row(for result: GradeResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    result.studentName.isEmpty
                    ? "بدون اسم"
                    : result.studentName
                )
                .font(.headline)

                Text(
                    "\(result.studentId.isEmpty ? "—" : result.studentId) · \(result.templateName)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(result.percentage, specifier: "%.0f")%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(
                        result.percentage >= 50 ? .green : .red
                    )

                if result.ambiguousCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? resultsStore.delete(filteredResults[index])
        }
    }
}


/// يحمّل الصورة المصححة المخزّنة على القرص قبل عرض ResultsView
private struct HistoryDetailLoader: View {
    let result: GradeResult
    
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                ResultsView(
                    result: result,
                    alignedImage: image
                )
            } else {
                ProgressView()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let path = result.correctedImagePath else {
            return
        }

        let url = AppDirectories.scannedImagesDirectory
            .appendingPathComponent(path)

        guard
            let data = try? Data(contentsOf: url),
            let uiImage = UIImage(data: data),
            let cg = uiImage.cgImage
        else {
            return
        }

        image = cg
    }
}


#Preview {
    HistoryView()
        .environmentObject(ResultsStore())
        .environmentObject(TemplateStore())
}
