//
//  Colour.swift
//  ColourKit
//
//  Created by Jarrod Norwell on 27/11/2025.
//

import SwiftUI
import UIKit

public extension Colour {
    var uiColour: UIColour { UIColour(self) }
    
    static let vibrantBlues: [Colour] = [
        Colour(red: 0.70, green: 0.85, blue: 1.00),
        Colour(red: 0.55, green: 0.75, blue: 1.00),
        Colour(red: 0.40, green: 0.65, blue: 1.00),
        Colour(red: 0.30, green: 0.55, blue: 0.95),
        Colour(red: 0.20, green: 0.45, blue: 0.90),
        Colour(red: 0.15, green: 0.40, blue: 0.80),
        Colour(red: 0.10, green: 0.35, blue: 0.70),
        Colour(red: 0.05, green: 0.30, blue: 0.60),
        Colour(red: 0.00, green: 0.25, blue: 0.50)
    ]
    
    static let vibrantBrowns: [Colour] = [
        Colour(red: 0.95, green: 0.90, blue: 0.80),
        Colour(red: 0.90, green: 0.80, blue: 0.65),
        Colour(red: 0.85, green: 0.70, blue: 0.50),
        Colour(red: 0.80, green: 0.60, blue: 0.40),
        Colour(red: 0.70, green: 0.50, blue: 0.30),
        Colour(red: 0.60, green: 0.40, blue: 0.25),
        Colour(red: 0.50, green: 0.30, blue: 0.20),
        Colour(red: 0.40, green: 0.25, blue: 0.15),
        Colour(red: 0.30, green: 0.20, blue: 0.10)
    ]
    
    static let vibrantGolds: [Colour] = [
        Colour(red: 1.00, green: 0.95, blue: 0.80),
        Colour(red: 1.00, green: 0.90, blue: 0.60),
        Colour(red: 1.00, green: 0.85, blue: 0.45),
        Colour(red: 0.98, green: 0.80, blue: 0.30),
        Colour(red: 0.95, green: 0.75, blue: 0.15),
        Colour(red: 0.90, green: 0.65, blue: 0.10),
        Colour(red: 0.85, green: 0.55, blue: 0.05),
        Colour(red: 0.75, green: 0.45, blue: 0.05),
        Colour(red: 0.65, green: 0.35, blue: 0.05)
    ]
    
    static let vibrantGreens: [Colour] = [
        Colour(red: 0.70, green: 1.00, blue: 0.70),
        Colour(red: 0.55, green: 0.95, blue: 0.55),
        Colour(red: 0.40, green: 0.90, blue: 0.50),
        Colour(red: 0.30, green: 0.85, blue: 0.45),
        Colour(red: 0.20, green: 0.80, blue: 0.40),
        Colour(red: 0.10, green: 0.75, blue: 0.35),
        Colour(red: 0.05, green: 0.65, blue: 0.35),
        Colour(red: 0.00, green: 0.55, blue: 0.35),
        Colour(red: 0.00, green: 0.45, blue: 0.30)
    ]
    
    static let vibrantMints: [Colour] = [
        Colour(red: 0.85, green: 1.00, blue: 0.90),
        Colour(red: 0.75, green: 1.00, blue: 0.85),
        Colour(red: 0.65, green: 1.00, blue: 0.80),
        Colour(red: 0.55, green: 0.95, blue: 0.75),
        Colour(red: 0.45, green: 0.90, blue: 0.70),
        Colour(red: 0.35, green: 0.85, blue: 0.65),
        Colour(red: 0.25, green: 0.75, blue: 0.60),
        Colour(red: 0.20, green: 0.65, blue: 0.55),
        Colour(red: 0.15, green: 0.55, blue: 0.50)
    ]
    
    static let vibrantOranges: [Colour] = [
        Colour(red: 1.00, green: 0.85, blue: 0.70),
        Colour(red: 1.00, green: 0.75, blue: 0.55),
        Colour(red: 1.00, green: 0.65, blue: 0.40),
        Colour(red: 1.00, green: 0.55, blue: 0.25),
        Colour(red: 1.00, green: 0.45, blue: 0.10),
        Colour(red: 0.90, green: 0.40, blue: 0.05),
        Colour(red: 0.80, green: 0.35, blue: 0.05),
        Colour(red: 0.70, green: 0.30, blue: 0.05),
        Colour(red: 0.60, green: 0.25, blue: 0.05)
    ]
    
    static let vibrantPinks: [Colour] = [
        Colour(red: 1.00, green: 0.85, blue: 0.90),
        Colour(red: 1.00, green: 0.75, blue: 0.85),
        Colour(red: 1.00, green: 0.65, blue: 0.80),
        Colour(red: 1.00, green: 0.55, blue: 0.75),
        Colour(red: 1.00, green: 0.45, blue: 0.70),
        Colour(red: 0.95, green: 0.35, blue: 0.65),
        Colour(red: 0.90, green: 0.25, blue: 0.60),
        Colour(red: 0.80, green: 0.20, blue: 0.55),
        Colour(red: 0.70, green: 0.10, blue: 0.50)
    ]
    
    static let vibrantPurples: [Colour] = [
        Colour(red: 0.90, green: 0.85, blue: 1.00),
        Colour(red: 0.80, green: 0.70, blue: 1.00),
        Colour(red: 0.70, green: 0.55, blue: 1.00),
        Colour(red: 0.60, green: 0.45, blue: 0.95),
        Colour(red: 0.55, green: 0.35, blue: 0.90),
        Colour(red: 0.50, green: 0.30, blue: 0.80),
        Colour(red: 0.45, green: 0.25, blue: 0.70),
        Colour(red: 0.40, green: 0.20, blue: 0.60),
        Colour(red: 0.35, green: 0.15, blue: 0.50)
    ]
    
    static let vibrantRainbow: [Colour] = [
        Colour(red: 1.00, green: 0.30, blue: 0.30),
        Colour(red: 1.00, green: 0.55, blue: 0.20),
        Colour(red: 1.00, green: 0.90, blue: 0.25),
        Colour(red: 0.30, green: 0.85, blue: 0.30),
        Colour(red: 0.00, green: 0.65, blue: 0.85),
        Colour(red: 0.20, green: 0.45, blue: 0.90),
        Colour(red: 0.45, green: 0.35, blue: 0.85),
        Colour(red: 0.70, green: 0.40, blue: 0.85),
        Colour(red: 0.90, green: 0.35, blue: 0.70)
    ]
    
    static let vibrantReds: [Colour] = [
        Colour(red: 1.00, green: 0.75, blue: 0.75),
        Colour(red: 1.00, green: 0.60, blue: 0.60),
        Colour(red: 1.00, green: 0.50, blue: 0.50),
        Colour(red: 0.95, green: 0.40, blue: 0.40),
        Colour(red: 0.90, green: 0.30, blue: 0.30),
        Colour(red: 0.80, green: 0.20, blue: 0.20),
        Colour(red: 0.70, green: 0.15, blue: 0.15),
        Colour(red: 0.60, green: 0.10, blue: 0.10),
        Colour(red: 0.50, green: 0.05, blue: 0.05)
    ]
    
    static let vibrantViolets: [Colour] = [
        Colour(red: 0.90, green: 0.80, blue: 1.00),
        Colour(red: 0.80, green: 0.65, blue: 1.00),
        Colour(red: 0.70, green: 0.55, blue: 1.00),
        Colour(red: 0.60, green: 0.45, blue: 0.95),
        Colour(red: 0.50, green: 0.35, blue: 0.90),
        Colour(red: 0.45, green: 0.30, blue: 0.80),
        Colour(red: 0.40, green: 0.25, blue: 0.70),
        Colour(red: 0.35, green: 0.20, blue: 0.60),
        Colour(red: 0.30, green: 0.15, blue: 0.50)
    ]
    
    static let vibrantYellows: [Colour] = [
        Colour(red: 1.00, green: 0.98, blue: 0.80),
        Colour(red: 1.00, green: 0.95, blue: 0.60),
        Colour(red: 1.00, green: 0.90, blue: 0.40),
        Colour(red: 1.00, green: 0.85, blue: 0.25),
        Colour(red: 1.00, green: 0.80, blue: 0.10),
        Colour(red: 0.95, green: 0.75, blue: 0.05),
        Colour(red: 0.90, green: 0.65, blue: 0.00),
        Colour(red: 0.80, green: 0.55, blue: 0.00),
        Colour(red: 0.70, green: 0.45, blue: 0.00)
    ]
}
