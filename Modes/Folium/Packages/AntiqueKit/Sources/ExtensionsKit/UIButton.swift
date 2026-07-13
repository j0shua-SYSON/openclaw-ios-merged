//
//  UIButton.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 7/6/2026.
//

import ColourKit
import UIKit

public typealias Actions = (touchDown: (UIAction) async -> Void, touchUpInsideOutside: (UIAction) async -> Void)

public extension UIButton {
    static func button(with configuration: Configuration, actions: Actions, _ menu: UIMenu? = nil) -> UIButton {
        let button: UIButton = .init(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        if let menu {
            button.menu = menu
            button.showsMenuAsPrimaryAction = true
        } else {
            button.addAction(UIAction { action in
                Task {
                    await actions.touchDown(action)
                }
            }, for: .touchDown)
            
            button.addAction(UIAction { action in
                Task {
                    await actions.touchUpInsideOutside(action)
                }
            }, for: .touchUpInside)
            
            button.addAction(UIAction { action in
                Task {
                    await actions.touchUpInsideOutside(action)
                }
            }, for: .touchUpOutside)
        }
        
        if #unavailable(iOS 26) {
            button.layer.shadowColor = UIColour.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 10)
            button.layer.shadowOpacity = 1 / 5
            button.layer.shadowRadius = 20
        }
        
        return button
    }
}

@available(iOS 26, *)
public extension UIButton.Configuration {
    static func glassConfiguration(_ size: Size, _ cornerStyle: CornerStyle,
                                   _ image: UIImage? = nil, _ text: String? = nil, _ scale: UIImage.SymbolScale = .large,
                                   _ tintColor: UIColour? = nil) -> UIButton.Configuration {
        var configuration: UIButton.Configuration = if tintColor == nil {
            .glass()
        } else {
            .prominentGlass()
        }
        
        if let tintColor {
            configuration.baseBackgroundColor = .clear
            configuration.baseForegroundColor = tintColor
        }
        
        configuration.buttonSize = size
        configuration.cornerStyle = cornerStyle
        
        if let image {
            configuration.image = image
                .applyingSymbolConfiguration(UIImage.SymbolConfiguration(scale: scale))
        }
        
        if let text {
            configuration.title = text
        }
        
        return configuration
    }
}

public extension UIButton.Configuration {
    static func filledConfiguration(_ size: Size, _ cornerStyle: CornerStyle,
                                    _ image: UIImage? = nil, _ text: String? = nil, _ scale: UIImage.SymbolScale = .large) -> UIButton.Configuration {
        var configuration: UIButton.Configuration = .filled()
        configuration.baseBackgroundColor = .label
        configuration.baseForegroundColor = .systemBackground
        configuration.buttonSize = size
        configuration.cornerStyle = cornerStyle
        
        if let image {
            configuration.image = image
                .applyingSymbolConfiguration(UIImage.SymbolConfiguration(scale: scale))
        }
        
        if let text {
            configuration.title = text
        }
        
        return configuration
    }
}

public extension UIButton.Configuration {
    static func configuration(_ size: Size, _ cornerStyle: CornerStyle,
                              _ image: UIImage? = nil, _ text: String? = nil, _ scale: UIImage.SymbolScale? = .large,
                              _ tintColor: UIColour? = nil) -> UIButton.Configuration {
        if #available(iOS 26, *) {
            glassConfiguration(size, cornerStyle, image, text, scale ?? .large, tintColor)
        } else {
            filledConfiguration(size, cornerStyle, image, text, scale ?? .large)
        }
    }
}
