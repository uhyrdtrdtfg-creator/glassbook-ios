import SwiftUI

/// Spec §7.3 · 8-base spacing system.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 48
}

/// Spec §7.4 · Corner radii.
enum Radius {
    static let sm: CGFloat = 10   // small chips / icon tiles
    static let md: CGFloat = 14   // buttons, tabs
    static let lg: CGFloat = 22   // cards (default)
    static let xl: CGFloat = 28   // hero cards
    static let full: CGFloat = 999
}
