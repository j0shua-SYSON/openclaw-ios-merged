//
//  OBControllerWithListConfiguration 2.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 13/5/2026.
//

import ColourKit
import SwiftUI
import UIKit

public struct OBControllerConfiguration {
    public var image: UIImage? = nil
    public var textConfiguration, secondaryConfiguration: LabelConfiguration
    public var tertiaryConfiguration: LabelConfiguration? = nil
    
    public let buttons: [(configuration: UIButton.Configuration, action: @MainActor (UIViewController) async -> Void)]
    
    var colors: [Colour] = Colour.vibrantBlues
    
    public init(image: UIImage? = nil,
                textConfiguration: LabelConfiguration, secondaryConfiguration: LabelConfiguration, tertiaryConfiguration: LabelConfiguration? = nil,
                buttons: [(configuration: UIButton.Configuration, action: @MainActor (UIViewController) async -> Void)],
                colors: [Colour] = Colour.vibrantBlues) {
        self.image = image
        self.textConfiguration = textConfiguration
        self.secondaryConfiguration = secondaryConfiguration
        self.tertiaryConfiguration = tertiaryConfiguration
        self.buttons = buttons
        self.colors = colors
    }
}
