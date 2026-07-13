//
//  ConstraintKit.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 13/5/2026.
//

import UIKit

public extension UILayoutGuide {
    var top: NSLayoutYAxisAnchor { topAnchor }
    var left: NSLayoutXAxisAnchor { leftAnchor }
    var bottom: NSLayoutYAxisAnchor { bottomAnchor }
    var right: NSLayoutXAxisAnchor { rightAnchor }
    
    var centerX: NSLayoutXAxisAnchor { centerXAnchor }
    var centerY: NSLayoutYAxisAnchor { centerYAnchor }
    
    var height: NSLayoutDimension { heightAnchor }
    var width: NSLayoutDimension { widthAnchor }
}

public extension UIView {
    var top: NSLayoutYAxisAnchor { topAnchor }
    var left: NSLayoutXAxisAnchor { leftAnchor }
    var bottom: NSLayoutYAxisAnchor { bottomAnchor }
    var right: NSLayoutXAxisAnchor { rightAnchor }
    
    var centerX: NSLayoutXAxisAnchor { centerXAnchor }
    var centerY: NSLayoutYAxisAnchor { centerYAnchor }
    
    var height: NSLayoutDimension { heightAnchor }
    var width: NSLayoutDimension { widthAnchor }

    var salg: UILayoutGuide { safeAreaLayoutGuide }
}
