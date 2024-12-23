import Foundation

public protocol Logger {
    func info(_ string: String)
    func error(_ string: String)
}

struct PrintLogger: Logger {
    func info(_ string: String) {
        print("[Reeeed] ℹ️ \(string)")
    }
    func error(_ string: String) {
        print("[Reeeed] 🚨 \(string)")
    }
}

public enum Reeeed {
    public static var logger: Logger = PrintLogger()

    public static func warmup(extractor: Extractor) {
        switch extractor {
        case .mercury:
            MercuryExtractor.shared.warmUp()
        case .readability:
            ReadabilityExtractor.shared.warmUp()
        }
    }

    public static func extractArticleContent(url: URL, html: String, extractor: Extractor) async throws -> ExtractedContent {
        return try await withCheckedThrowingContinuation({ continuation in
            DispatchQueue.main.async {
                switch extractor {
                case .mercury:
                    MercuryExtractor.shared.extract(html: html, url: url) { contentOpt in
                        if let content = contentOpt {
                            continuation.resume(returning: content)
                        } else {
                            continuation.resume(throwing: ExtractionError.FailedToExtract)
                        }
                    }
                case .readability:
                    ReadabilityExtractor.shared.extract(html: html, url: url) { contentOpt in
                        if let content = contentOpt {
                            continuation.resume(returning: content)
                        } else {
                            continuation.resume(throwing: ExtractionError.FailedToExtract)
                        }
                    }
                }
            }
        })
    }

    public struct FetchAndExtractionResult {
        public var metadata: SiteMetadata?
        public var extracted: ExtractedContent
        public var styledHTML: String
        public var baseURL: URL

        public var title: String? {
            extracted.title?.nilIfEmpty ?? metadata?.title?.nilIfEmpty
        }
    }

    public static func fetchAndExtractContent(fromURL url: URL, extractor: Extractor) async throws -> ReadableDoc {
        DispatchQueue.main.async {
            Reeeed.warmup(extractor: extractor)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ExtractionError.DataIsNotString
        }
        let baseURL = response.url ?? url
        let content = try await Reeeed.extractArticleContent(url: baseURL, html: html, extractor: extractor)
        let extractedMetadata = try? await SiteMetadata.extractMetadata(fromHTML: html, baseURL: baseURL)
        
        guard let doc =  ReadableDoc(
            extracted: content,
            insertHeroImage: nil,
            metadata: extractedMetadata ?? SiteMetadata(url: url),
            date: content.datePublished)
        else {
            throw ExtractionError.MissingExtractionData
        }
        
        return doc
    }
}
