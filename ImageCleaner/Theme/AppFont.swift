import SwiftUI
import UIKit
import CoreText

enum AppFont {
    // Weight axis tag for variable fonts ('wght' as UInt32)
    private static let weightAxisTag: UInt32 = 0x77676874

    // Cache the base CGFont loaded from the variable font file
    private static let variableCGFont: CGFont? = {
        guard let url = Bundle.main.url(forResource: "Jost-VariableFont_wght", withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider) else {
            return nil
        }
        return cgFont
    }()

    static var largeTitle: Font { jost(size: 34, weight: 700) }
    static var title: Font { jost(size: 28, weight: 700) }
    static var title2: Font { jost(size: 22, weight: 500) }
    static var title3: Font { jost(size: 20, weight: 500) }
    static var headline: Font { jost(size: 17, weight: 700) }
    static var body: Font { jost(size: 17, weight: 500) }
    static var callout: Font { jost(size: 16, weight: 500) }
    static var subheadline: Font { jost(size: 15, weight: 500) }
    static var footnote: Font { jost(size: 13, weight: 500) }
    static var caption: Font { jost(size: 12, weight: 500) }

    /// Jost variable font with any weight from 100-900.
    /// Loads directly from the bundled Jost-VariableFont_wght.ttf file.
    /// 100=Thin, 200=ExtraLight, 300=Light, 400=Regular, 500=Medium, 600=SemiBold, 700=Bold, 800=ExtraBold, 900=Black
    static func jost(size: CGFloat, weight: CGFloat) -> Font {
        guard let cgFont = variableCGFont else {
            // Fallback to static font if variable font not available
            return Font.custom("Jost-Medium", size: size)
        }

        // Create a CTFont from the CGFont
        let ctFont = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)

        // Create a variation descriptor with the desired weight
        let variationDescriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontVariationAttribute: [weightAxisTag: weight] as CFDictionary
        ] as CFDictionary)

        // Apply the variation to create the final font
        let variedFont = CTFontCreateCopyWithAttributes(ctFont, size, nil, variationDescriptor)

        return Font(variedFont as UIFont)
    }
}
