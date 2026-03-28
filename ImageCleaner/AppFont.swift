import SwiftUI

enum AppFont {
    static let largeTitle = Font.custom("Futura-Bold", size: 34, relativeTo: .largeTitle)
    static let title = Font.custom("Futura-Bold", size: 28, relativeTo: .title)
    static let title2 = Font.custom("Futura-Medium", size: 22, relativeTo: .title2)
    static let title3 = Font.custom("Futura-Medium", size: 20, relativeTo: .title3)
    static let headline = Font.custom("Futura-Bold", size: 17, relativeTo: .headline)
    static let body = Font.custom("Futura-Medium", size: 17, relativeTo: .body)
    static let callout = Font.custom("Futura-Medium", size: 16, relativeTo: .callout)
    static let subheadline = Font.custom("Futura-Medium", size: 15, relativeTo: .subheadline)
    static let footnote = Font.custom("Futura-Medium", size: 13, relativeTo: .footnote)
    static let caption = Font.custom("Futura-Medium", size: 12, relativeTo: .caption)
}
