import CoreImage.CIFilterBuiltins
import UIKit

/// The link code as a QR code: the child's phone shows it, the parent's phone scans it instead of
/// typing the 6 characters. Same text as `ParentLinkQr` on Android, so the two phones scan each
/// other.
enum ParentLinkQR {
  private static let prefix = "NOTIS-OUDER:"
  private static let codeLength = 6

  static func payload(_ code: String) -> String {
    prefix + code
  }

  /// The link code in scanned text: ours with the prefix, or just the 6 characters.
  static func parse(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let raw =
      trimmed.uppercased().hasPrefix(prefix)
      ? String(trimmed.dropFirst(prefix.count)) : trimmed
    let code = raw.uppercased().filter { $0.isLetter || $0.isNumber }
    let rawLength = raw.trimmingCharacters(in: .whitespaces).count
    return code.count == codeLength && rawLength == codeLength ? code : nil
  }

  /// A sharp black-on-white QR image of [code].
  static func image(_ code: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(payload(code).utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
      let cgImage = CIContext().createCGImage(output, from: output.extent)
    else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
