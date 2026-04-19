import Foundation
import UIKit
import SwiftUI

/// Spec v2 V2.0 roadmap · 发票抵扣 PDF 导出.
/// Renders a selected transaction slice to a multi-page A4 PDF using
/// UIGraphicsPDFRenderer. Returned as URL so `ShareLink` can hand it off.
enum PDFExporter {

    static let pageWidth: CGFloat = 595   // A4 @ 72 dpi
    static let pageHeight: CGFloat = 842
    static let margin: CGFloat = 40

    struct ExportCriteria {
        var startDate: Date
        var endDate: Date
        var categoryFilter: Set<Category.Slug>   // empty = all
        var title: String
        var author: String
    }

    struct ExportResult {
        let url: URL
        let txCount: Int
        let totalCents: Int
    }

    static func export(transactions allTx: [Transaction], criteria: ExportCriteria) throws -> ExportResult {
        let rows = allTx.filter { tx in
            guard tx.kind == .expense else { return false }
            if tx.timestamp < criteria.startDate || tx.timestamp > criteria.endDate { return false }
            if criteria.categoryFilter.isEmpty { return true }
            return criteria.categoryFilter.contains(tx.categoryID)
        }
        .sorted { $0.timestamp > $1.timestamp }

        let totalCents = rows.reduce(0) { $0 + $1.amountCents }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: criteria.title,
            kCGPDFContextAuthor as String: criteria.author,
            kCGPDFContextCreator as String: "Glassbook",
        ]
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        let data = renderer.pdfData { ctx in
            var yCursor: CGFloat = margin
            ctx.beginPage()
            yCursor = drawHeader(criteria: criteria, count: rows.count, total: totalCents, y: yCursor)
            yCursor = drawTableHead(y: yCursor)
            for tx in rows {
                if yCursor + 24 > pageHeight - margin {
                    drawFooter(pageIndex: ctx.pdfContextBounds.size.height.hashValue)
                    ctx.beginPage()
                    yCursor = margin
                    yCursor = drawTableHead(y: yCursor)
                }
                yCursor = drawRow(tx: tx, y: yCursor)
            }
            yCursor = drawTotal(total: totalCents, y: yCursor + 12)
            drawFooter(pageIndex: 0)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Glassbook-\(Self.fileStamp()).pdf")
        try data.write(to: url)
        return ExportResult(url: url, txCount: rows.count, totalCents: totalCents)
    }

    // MARK: - Drawing helpers

    @discardableResult
    private static func drawHeader(criteria: ExportCriteria, count: Int, total: Int, y: CGFloat) -> CGFloat {
        var y = y
        let title = criteria.title as NSString
        title.draw(at: CGPoint(x: margin, y: y),
                   withAttributes: [
                    .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                    .foregroundColor: UIColor(Color(hex: 0x1A1A2E)),
                   ])
        y += 34

        let dateRange = "\(dateFmt.string(from: criteria.startDate)) – \(dateFmt.string(from: criteria.endDate))"
        (dateRange as NSString).draw(at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ])
        y += 18

        let meta = "共 \(count) 笔 · 合计 \(Money.yuan(total, showDecimals: true)) · 报销人 \(criteria.author)"
        (meta as NSString).draw(at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ])
        y += 24
        UIColor.lightGray.setStroke()
        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: margin, y: y))
        sep.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        sep.lineWidth = 0.5
        sep.stroke()
        y += 14
        return y
    }

    @discardableResult
    private static func drawTableHead(y: CGFloat) -> CGFloat {
        let heads: [(String, CGFloat)] = [
            ("日期",    margin),
            ("商户",    margin + 110),
            ("分类",    margin + 300),
            ("金额",    pageWidth - margin - 80),
        ]
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.gray,
        ]
        for (text, x) in heads {
            (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        }
        return y + 18
    }

    @discardableResult
    private static func drawRow(tx: Transaction, y: CGFloat) -> CGFloat {
        let cat = Category.by(tx.categoryID)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor(Color(hex: 0x1A1A2E)),
        ]
        (rowDateFmt.string(from: tx.timestamp) as NSString)
            .draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        (tx.merchant as NSString)
            .draw(at: CGPoint(x: margin + 110, y: y), withAttributes: attrs)
        ("\(cat.emoji) \(cat.name)" as NSString)
            .draw(at: CGPoint(x: margin + 300, y: y), withAttributes: attrs)

        let amt = Money.yuan(tx.amountCents, showDecimals: true) as NSString
        let amtAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(Color(hex: 0x1A1A2E)),
        ]
        amt.draw(at: CGPoint(x: pageWidth - margin - 80, y: y), withAttributes: amtAttrs)
        return y + 18
    }

    @discardableResult
    private static func drawTotal(total: Int, y: CGFloat) -> CGFloat {
        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: margin, y: y))
        sep.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        UIColor.lightGray.setStroke()
        sep.lineWidth = 0.5
        sep.stroke()
        let y2 = y + 12
        let lbl = "合计" as NSString
        lbl.draw(at: CGPoint(x: margin, y: y2),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor(Color(hex: 0x1A1A2E)),
            ])
        let amt = Money.yuan(total, showDecimals: true) as NSString
        amt.draw(at: CGPoint(x: pageWidth - margin - 80, y: y2),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor(Color(hex: 0xD04A7A)),
            ])
        return y2 + 18
    }

    private static func drawFooter(pageIndex: Int) {
        let text = "Glassbook · Local-first bookkeeping · 本 PDF 在设备生成,未经任何服务器"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.lightGray,
        ]
        (text as NSString).draw(
            at: CGPoint(x: margin, y: pageHeight - margin + 10),
            withAttributes: attrs
        )
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "zh_CN"); f.dateFormat = "yyyy年M月d日"; return f
    }()
    private static let rowDateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM/dd"; return f
    }()
    private static func fileStamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: .now)
    }
}
