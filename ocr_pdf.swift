import Foundation
import PDFKit
import Vision
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: ocr_pdf.swift <pdf> [page|all]\n", stderr)
    exit(1)
}

let pdfURL = URL(fileURLWithPath: args[1])
let pageArg = args.count >= 3 ? args[2] : "all"

guard let document = PDFDocument(url: pdfURL) else {
    fputs("Could not open PDF\n", stderr)
    exit(1)
}

func cgImage(for page: PDFPage, scale: CGFloat = 2.5) -> CGImage? {
    let bounds = page.bounds(for: .mediaBox)
    let width = Int(bounds.width * scale)
    let height = Int(bounds.height * scale)
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.saveGState()
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    context.restoreGState()
    return context.makeImage()
}

func recognize(_ image: CGImage) throws -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US"]
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    let observations = request.results ?? []
    return observations.compactMap { $0.topCandidates(1).first?.string }
}

let pages: [Int]
if pageArg == "all" {
    pages = Array(0..<document.pageCount)
} else if let oneBased = Int(pageArg), oneBased >= 1, oneBased <= document.pageCount {
    pages = [oneBased - 1]
} else {
    fputs("Invalid page argument\n", stderr)
    exit(1)
}

for index in pages {
    guard let page = document.page(at: index), let image = cgImage(for: page) else {
        continue
    }
    print("--- PAGE \(index + 1) ---")
    do {
        for line in try recognize(image) {
            print(line)
        }
    } catch {
        fputs("OCR failed on page \(index + 1): \(error)\n", stderr)
    }
}
