//
//  LabelConfiguration.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 13/5/2026.
//

import UIKit

public struct LabelConfiguration : Equatable, Hashable, @unchecked Sendable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: UUID = UUID()
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public var alignment: NSTextAlignment
    public let color: UIColor
    public let font: UIFont
    public let text: String
    public var attributedText: AttributedString? = nil
    
    public init(alignment: NSTextAlignment, color: UIColor, font: UIFont, text: String, attributedText: AttributedString? = nil) {
        self.alignment = alignment
        self.color = color
        self.font = font
        self.text = text
        self.attributedText = attributedText
    }
}
