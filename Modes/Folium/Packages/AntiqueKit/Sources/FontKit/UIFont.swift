//
//  File.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 13/5/2026.
//

import UIKit

public extension UIFont {
    static func bold(from textStyle: TextStyle) -> UIFont {
        UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize)
    }
    
    static func regular(from textStyle: TextStyle) -> UIFont {
        UIFont.preferredFont(forTextStyle: textStyle)
    }
}
