//
//  CellConfiguration.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 13/5/2026.
//

import UIKit

public struct CellConfiguration : Equatable, Hashable, @unchecked Sendable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: UUID = UUID()
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public var image: UIImage? = nil
    public let labels: (primary: LabelConfiguration, secondary: LabelConfiguration)
    
    public init(image: UIImage? = nil, labels: (primary: LabelConfiguration, secondary: LabelConfiguration)) {
        self.image = image
        self.labels = labels
    }
}
