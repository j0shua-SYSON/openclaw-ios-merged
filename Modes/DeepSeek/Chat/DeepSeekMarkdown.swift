import SwiftUI

/// Lightweight block-level Markdown renderer for assistant messages, styled to
/// match DeepSeek: bold section headers, `•`/numbered lists, hairline dividers,
/// inline `code`, and fenced code blocks on a tinted surface. Inline styling
/// (bold/italic/code/links) uses the system AttributedString markdown parser.
///
/// Math (LaTeX/KaTeX) and Mermaid are rendered as monospaced source for now — a
/// WKWebView+KaTeX pass is the fidelity follow-up for those.
struct DSMarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(Self.parse(text).enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func render(_ block: Block) -> some View {
        switch block {
        case let .heading(level, s):
            Self.inline(s)
                .font(.system(size: level <= 1 ? 20 : level == 2 ? 18 : 16, weight: .semibold))
                .foregroundStyle(DS.Palette.textPrimary)
                .padding(.top, 2)
        case let .paragraph(s):
            Self.inline(s)
                .font(DS.Font.body)
                .foregroundStyle(DS.Palette.textPrimary)
                .lineSpacing(DS.Metric.messageBodyLineSpacing)
        case let .bullet(items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").font(DS.Font.body).foregroundStyle(DS.Palette.textSecondary)
                        Self.inline(it).font(DS.Font.body).foregroundStyle(DS.Palette.textPrimary)
                            .lineSpacing(DS.Metric.messageBodyLineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case let .ordered(items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1).").font(DS.Font.body.weight(.medium)).foregroundStyle(DS.Palette.textSecondary)
                        Self.inline(it).font(DS.Font.body).foregroundStyle(DS.Palette.textPrimary)
                            .lineSpacing(DS.Metric.messageBodyLineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case let .code(source, _):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(source)
                    .font(DS.Font.code)
                    .foregroundStyle(DS.Palette.textPrimary)
                    .padding(12)
            }
            .background(DS.Palette.codeBlockBg, in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, alignment: .leading)
        case .rule:
            Divider().overlay(DS.Palette.separator)
        }
    }

    // MARK: Inline

    static func inline(_ s: String) -> Text {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let a = try? AttributedString(markdown: s, options: opts) { return Text(a) }
        return Text(s)
    }

    // MARK: Block parsing

    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case bullet([String])
        case ordered([String])
        case code(String, String)
        case rule
    }

    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var para: [String] = []
        func flushPara() {
            if !para.isEmpty { blocks.append(.paragraph(para.joined(separator: " ").trimmingCharacters(in: .whitespaces))); para = [] }
        }
        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)
            // fenced code
            if line.hasPrefix("```") {
                flushPara()
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i]); i += 1
                }
                blocks.append(.code(code.joined(separator: "\n"), lang))
                i += 1
                continue
            }
            if line.isEmpty { flushPara(); i += 1; continue }
            // horizontal rule
            if line == "---" || line == "***" || line == "___" { flushPara(); blocks.append(.rule); i += 1; continue }
            // heading
            if let h = headingLevel(line) { flushPara(); blocks.append(.heading(h.0, h.1)); i += 1; continue }
            // bullet list
            if isBullet(line) {
                flushPara()
                var items: [String] = []
                while i < lines.count, isBullet(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(stripBullet(lines[i].trimmingCharacters(in: .whitespaces))); i += 1
                }
                blocks.append(.bullet(items)); continue
            }
            // ordered list
            if isOrdered(line) {
                flushPara()
                var items: [String] = []
                while i < lines.count, isOrdered(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(stripOrdered(lines[i].trimmingCharacters(in: .whitespaces))); i += 1
                }
                blocks.append(.ordered(items)); continue
            }
            para.append(line); i += 1
        }
        flushPara()
        return blocks
    }

    private static func headingLevel(_ s: String) -> (Int, String)? {
        var n = 0
        for c in s { if c == "#" { n += 1 } else { break } }
        guard n >= 1, n <= 6, s.count > n, s[s.index(s.startIndex, offsetBy: n)] == " " else { return nil }
        return (n, String(s.dropFirst(n)).trimmingCharacters(in: .whitespaces))
    }
    private static func isBullet(_ s: String) -> Bool { s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ") || s.hasPrefix("• ") }
    private static func stripBullet(_ s: String) -> String { String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
    private static func isOrdered(_ s: String) -> Bool {
        guard let dot = s.firstIndex(of: ".") else { return false }
        let num = s[s.startIndex..<dot]
        return !num.isEmpty && num.allSatisfy(\.isNumber) && s.index(after: dot) < s.endIndex && s[s.index(after: dot)] == " "
    }
    private static func stripOrdered(_ s: String) -> String {
        guard let dot = s.firstIndex(of: ".") else { return s }
        return String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
    }
}
