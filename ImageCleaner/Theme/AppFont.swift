import SwiftUI
import CoreText

@MainActor
enum AppFont {
    // Weight axis tag for variable fonts ('wght' as UInt32)
    private static let weightAxisTag: UInt32 = 0x77676874

    // Cache the base CGFont loaded from the variable font file
    nonisolated(unsafe) private static let variableCGFont: CGFont? = {
        guard let url = Bundle.main.url(forResource: "Jost-VariableFont_wght", withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider) else {
            return nil
        }
        return cgFont
    }()

    static var largeTitle: Font { jost(size: 34, relativeTo: .largeTitle, weight: 700) }
    static var title: Font { jost(size: 28, relativeTo: .title1, weight: 700) }
    static var title2: Font { jost(size: 22, relativeTo: .title2, weight: 500) }
    static var title3: Font { jost(size: 20, relativeTo: .title3, weight: 500) }
    static var headline: Font { jost(size: 17, relativeTo: .headline, weight: 700) }
    static var body: Font { jost(size: 17, relativeTo: .body, weight: 500) }
    static var callout: Font { jost(size: 16, relativeTo: .callout, weight: 500) }
    static var subheadline: Font { jost(size: 15, relativeTo: .subheadline, weight: 500) }
    static var footnote: Font { jost(size: 13, relativeTo: .footnote, weight: 500) }
    static var caption: Font { jost(size: 12, relativeTo: .caption1, weight: 500) }

    /// Jost variable font with any weight from 100-900.
    /// Loads directly from the bundled Jost-VariableFont_wght.ttf file.
    /// 100=Thin, 200=ExtraLight, 300=Light, 400=Regular, 500=Medium, 600=SemiBold, 700=Bold, 800=ExtraBold, 900=Black
    ///
    /// When `relativeTo` is provided, the size scales with Dynamic Type via
    /// `UIFontMetrics`. When omitted, the font is fixed-size (used for hero display
    /// text like the SCAN wordmark where the layout depends on a stable width).
    static func jost(size: CGFloat, relativeTo style: UIFont.TextStyle? = nil, weight: CGFloat) -> Font {
        let scaledSize: CGFloat = {
            guard let style else { return size }
            return UIFontMetrics(forTextStyle: style).scaledValue(for: size)
        }()

        guard let cgFont = variableCGFont else {
            if let style = style.flatMap(Font.TextStyle.init) {
                return Font.custom("Jost-Medium", size: size, relativeTo: style)
            }
            return Font.custom("Jost-Medium", size: size)
        }

        let ctFont = CTFontCreateWithGraphicsFont(cgFont, scaledSize, nil, nil)
        let variationDescriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontVariationAttribute: [weightAxisTag: weight] as CFDictionary
        ] as CFDictionary)
        let variedFont = CTFontCreateCopyWithAttributes(ctFont, scaledSize, nil, variationDescriptor)

        return Font(variedFont as UIFont)
    }
}

private extension Font.TextStyle {
    init?(_ uiStyle: UIFont.TextStyle) {
        switch uiStyle {
        case .largeTitle: self = .largeTitle
        case .title1: self = .title
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .body: self = .body
        case .callout: self = .callout
        case .subheadline: self = .subheadline
        case .footnote: self = .footnote
        case .caption1: self = .caption
        case .caption2: self = .caption2
        default: return nil
        }
    }
}
