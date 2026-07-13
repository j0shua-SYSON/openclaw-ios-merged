//
//  OBController.swift
//  OnboardingKit
//
//  Created by Jarrod Norwell on 21/9/2025.
//

import ColourKit
import FontKit
import SwiftUI
import UIKit

extension UIView {
    var removeFromSuperview: Void {
        removeFromSuperview()
    }
}

extension UIViewController {
    var iPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    func interfaceOrientation() -> UIInterfaceOrientation {
        guard let window = view.window, let windowScene = window.windowScene else {
            return switch UIDevice.current.orientation {
            case .portrait:
                .portrait
            case .landscapeLeft:
                .landscapeLeft
            case .landscapeRight:
                .landscapeRight
            default:
                .portrait
            }
        }
        
        return windowScene.effectiveGeometry.interfaceOrientation
    }
}


open class OBController : UIViewController {
    var leftContainerView: UIView? = nil,
        rightContainerView: UIView? = nil
    
    var vibrancyVisualEffectView: UIVisualEffectView? = nil
    
    var imageView: UIImageView? = nil
    
    var textLabel: UILabel? = nil,
        secondaryTextLabel: UILabel? = nil,
        tertiaryTextLabel: UILabel? = nil
    
    var stackView: UIStackView? = nil
    
    // portrait, landscape
    var constraints: (portrait: [NSLayoutConstraint], landscape: [NSLayoutConstraint]) = ([], [])
    
    var configuration: OBControllerConfiguration
    public init(configuration: OBControllerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            self.configuration.textConfiguration.alignment = .right
            self.configuration.secondaryConfiguration.alignment = .right
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 18.0, *) {
            view.backgroundColor = .clear
            
            let hostingController: UIHostingController = UIHostingController(rootView: MeshGradientView(colours: configuration.colors))
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            addChild(hostingController)
            view.insertSubview(hostingController.view, belowSubview: view)
            hostingController.didMove(toParent: self)
            
            hostingController.view.top.constraint(equalTo: view.top).isActive = true
            hostingController.view.left.constraint(equalTo: view.left).isActive = true
            hostingController.view.bottom.constraint(equalTo: view.bottom).isActive = true
            hostingController.view.right.constraint(equalTo: view.right).isActive = true
            
            let visualEffectView: UIVisualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            visualEffectView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(visualEffectView)
            
            visualEffectView.top.constraint(equalTo: view.top).isActive = true
            visualEffectView.left.constraint(equalTo: view.left).isActive = true
            visualEffectView.bottom.constraint(equalTo: view.bottom).isActive = true
            visualEffectView.right.constraint(equalTo: view.right).isActive = true
            
            vibrancyVisualEffectView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .systemMaterial)))
            guard let vibrancyVisualEffectView else {
                return
            }
            vibrancyVisualEffectView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(vibrancyVisualEffectView)
            
            vibrancyVisualEffectView.top.constraint(equalTo: view.top).isActive = true
            vibrancyVisualEffectView.left.constraint(equalTo: view.left).isActive = true
            vibrancyVisualEffectView.bottom.constraint(equalTo: view.bottom).isActive = true
            vibrancyVisualEffectView.right.constraint(equalTo: view.right).isActive = true
        } else {
            view.backgroundColor = .systemBackground
        }
        
        let subviewToAddSubviews: UIView = vibrancyVisualEffectView?.contentView ?? view
        let isPortrait: Bool = UIDevice.current.userInterfaceIdiom == .pad || interfaceOrientation().isPortrait
        
        leftContainerView = UIView()
        guard let leftContainerView else {
            return
        }
        leftContainerView.translatesAutoresizingMaskIntoConstraints = false
        subviewToAddSubviews.addSubview(leftContainerView)
        
        rightContainerView = UIView()
        guard let rightContainerView else {
            return
        }
        rightContainerView.translatesAutoresizingMaskIntoConstraints = false
        subviewToAddSubviews.addSubview(rightContainerView)
        
        imageView = UIImageView(image: configuration.image)
        guard let imageView else {
            return
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        (isPortrait ? subviewToAddSubviews : leftContainerView).addSubview(imageView)
        
        textLabel = UILabel()
        guard let textLabel else {
            return
        }
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = configuration.textConfiguration.font
        textLabel.numberOfLines = 1
        if let attributedText: AttributedString = configuration.textConfiguration.attributedText {
            textLabel.attributedText = NSAttributedString(attributedText)
        } else {
            textLabel.text = configuration.textConfiguration.text
        }
        textLabel.textAlignment = configuration.textConfiguration.alignment
        textLabel.textColor = configuration.textConfiguration.color
        (isPortrait ? subviewToAddSubviews : rightContainerView).addSubview(textLabel)
        
        secondaryTextLabel = UILabel()
        guard let secondaryTextLabel else {
            return
        }
        secondaryTextLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryTextLabel.font = configuration.secondaryConfiguration.font
        secondaryTextLabel.numberOfLines = 3
        if let attributedText: AttributedString = configuration.secondaryConfiguration.attributedText {
            secondaryTextLabel.attributedText = NSAttributedString(attributedText)
        } else {
            secondaryTextLabel.text = configuration.secondaryConfiguration.text
        }
        secondaryTextLabel.textAlignment = configuration.secondaryConfiguration.alignment
        secondaryTextLabel.textColor = configuration.secondaryConfiguration.color
        (isPortrait ? subviewToAddSubviews : rightContainerView).addSubview(secondaryTextLabel)
        
        if let tertiaryConfiguration: LabelConfiguration = configuration.tertiaryConfiguration, !tertiaryConfiguration.text.isEmpty {
            tertiaryTextLabel = UILabel()
            guard let tertiaryTextLabel else {
                return
            }
            tertiaryTextLabel.translatesAutoresizingMaskIntoConstraints = false
            tertiaryTextLabel.font = tertiaryConfiguration.font
            tertiaryTextLabel.numberOfLines = 3
            if let attributedText: AttributedString = tertiaryConfiguration.attributedText {
                tertiaryTextLabel.attributedText = NSAttributedString(attributedText)
            } else {
                tertiaryTextLabel.text = tertiaryConfiguration.text
            }
            tertiaryTextLabel.textAlignment = tertiaryConfiguration.alignment
            tertiaryTextLabel.textColor = tertiaryConfiguration.color
            (isPortrait ? subviewToAddSubviews : rightContainerView).addSubview(tertiaryTextLabel)
        }
        
        let mapped: [UIButton] = configuration.buttons.map { button in
            let button: UIButton = UIButton(configuration: button.configuration, primaryAction: UIAction { action in
                Task { @MainActor in
                    await button.action(self)
                }
            })
            return button
        }
        
        stackView = UIStackView(arrangedSubviews: mapped)
        guard let stackView else {
            return
        }
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.spacing = 20.0
        view.addSubview(stackView)
        
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            addConstraintsForPad()
        case .phone:
            addConstraintsForPhone()
        default:
            break
        }
        
        changeSubviewsForOrientation()
        changeConstraintsForOrientationChange()
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in } completion: { context in
            self.changeSubviewsForOrientation()
            self.changeConstraintsForOrientationChange()
        }
    }
    
    func changeConstraintsForOrientationChange() {
        guard let view: UIView else {
            return
        }
        
        var windowScene: UIWindowScene? = nil
        if let window: UIWindow = view.window, let currentWindowScene: UIWindowScene = window.windowScene {
            windowScene = currentWindowScene
        } else if let currentWindowScene: UIWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene = currentWindowScene
        } else {
            windowScene = nil
        }
        
        guard let windowScene: UIWindowScene else {
            return
        }
        
        switch windowScene.effectiveGeometry.interfaceOrientation {
        case .portrait:
            view.removeConstraints(constraints.landscape)
            view.addConstraints(constraints.portrait)
        case .landscapeLeft, .landscapeRight:
            view.removeConstraints(constraints.portrait)
            view.addConstraints(constraints.landscape)
        default:
            break
        }
    }
    
    func changeSubviewsForOrientation() {
        guard let view: UIView else {
            return
        }
        
        var windowScene: UIWindowScene? = nil
        if let window: UIWindow = view.window, let currentWindowScene: UIWindowScene = window.windowScene {
            windowScene = currentWindowScene
        } else if let currentWindowScene: UIWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene = currentWindowScene
        } else {
            windowScene = nil
        }
        
        guard let windowScene: UIWindowScene else {
            return
        }
        
        if windowScene.effectiveGeometry.interfaceOrientation.isPortrait {
            guard let leftContainerView, let rightContainerView else {
                return
            }
            
            leftContainerView.subviews.forEach(\.removeFromSuperview)
            rightContainerView.subviews.forEach(\.removeFromSuperview)
            
            guard let imageView, let textLabel, let secondaryTextLabel, let stackView else {
                return
            }
            
            let subviewToAddSubviews: UIView = vibrancyVisualEffectView?.contentView ?? view
            
            subviewToAddSubviews.addSubview(imageView)
            subviewToAddSubviews.addSubview(textLabel)
            subviewToAddSubviews.addSubview(secondaryTextLabel)
            view.addSubview(stackView)
            
            if let tertiaryTextLabel {
                subviewToAddSubviews.addSubview(tertiaryTextLabel)
            }
        } else {
            let subviewToAddSubviews: UIView = vibrancyVisualEffectView?.contentView ?? view
            
            subviewToAddSubviews.subviews.forEach(\.removeFromSuperview)
            
            guard let leftContainerView, let rightContainerView else {
                return
            }
            
            subviewToAddSubviews.addSubview(leftContainerView)
            subviewToAddSubviews.addSubview(rightContainerView)
            
            guard let imageView, let textLabel, let secondaryTextLabel, let stackView else {
                return
            }
            
            leftContainerView.addSubview(imageView)
            rightContainerView.addSubview(textLabel)
            rightContainerView.addSubview(secondaryTextLabel)
            view.addSubview(stackView)
            
            if let tertiaryTextLabel {
                rightContainerView.addSubview(tertiaryTextLabel)
            }
        }
    }
    
    func addConstraintsForPad() {
        guard let imageView, let textLabel, let secondaryTextLabel, let stackView else {
            return
        }
        
        let subviewToAddSubviews: UIView = vibrancyVisualEffectView?.contentView ?? view
        
        let imageWidthMultiplier: CGFloat = if configuration.textConfiguration.alignment == .center {
            1 / 4
        } else {
            1 / 6
        }
        
        constraints.portrait.append(contentsOf: [
            imageView.top.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.top, constant: 60.0),
            imageView.height.constraint(equalTo: imageView.safeAreaLayoutGuide.width),
            imageView.width.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.width, multiplier: imageWidthMultiplier),
            
            textLabel.top.constraint(equalTo: imageView.safeAreaLayoutGuide.bottom, constant: 20.0),
            secondaryTextLabel.top.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottom, constant: 8.0),
            
            stackView.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
            stackView.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
            stackView.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
        ])
        
        let portraitTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.textConfiguration.alignment {
        case .left:
            [
                imageView.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                
                textLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                imageView.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX),
                
                textLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                textLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                imageView.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                
                textLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.portrait.append(contentsOf: portraitTextAlignmentConstraints)
        
        let portraitSecondaryTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.textConfiguration.alignment {
        case .left:
            [
                secondaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                secondaryTextLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.portrait.append(contentsOf: portraitSecondaryTextAlignmentConstraints)
        
        if let tertiaryTextLabel {
            constraints.portrait.append(contentsOf: [
                tertiaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                tertiaryTextLabel.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom),
                tertiaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                
                stackView.bottom.constraint(equalTo: tertiaryTextLabel.safeAreaLayoutGuide.top, constant: -20.0)
            ])
        } else {
            constraints.portrait.append(contentsOf: [
                stackView.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom)
            ])
        }
        
        constraints.landscape.append(contentsOf: constraints.portrait)
    }
    
    func addConstraintsForPhone() {
        guard let imageView, let textLabel, let secondaryTextLabel, let stackView else {
            return
        }
        
        let subviewToAddSubviews: UIView = vibrancyVisualEffectView?.contentView ?? view
        
        let portraitStackViewLeftConstraint: NSLayoutConstraint =
            stackView.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0)
        portraitStackViewLeftConstraint.priority = .defaultLow
        let portraitStackViewRightConstraint: NSLayoutConstraint =
            stackView.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
        portraitStackViewRightConstraint.priority = .defaultLow
        
        constraints.portrait.append(contentsOf: [
            imageView.top.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.top, constant: 60.0),
            imageView.height.constraint(equalTo: imageView.safeAreaLayoutGuide.width),
            imageView.width.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.width, multiplier: 0.5),
            
            textLabel.top.constraint(equalTo: imageView.safeAreaLayoutGuide.bottom, constant: 20.0),
            secondaryTextLabel.top.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottom, constant: 8.0),
            
            portraitStackViewLeftConstraint,
            portraitStackViewRightConstraint,
            stackView.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
        ])
        
        let portraitTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.textConfiguration.alignment {
        case .left:
            [
                imageView.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                
                textLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                imageView.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX),
                
                textLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                textLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                imageView.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                
                textLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.portrait.append(contentsOf: portraitTextAlignmentConstraints)
        
        let portraitSecondaryTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.secondaryConfiguration.alignment {
        case .left:
            [
                secondaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                secondaryTextLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.portrait.append(contentsOf: portraitSecondaryTextAlignmentConstraints)
        
        if let tertiaryTextLabel {
            constraints.portrait.append(contentsOf: [
                tertiaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                tertiaryTextLabel.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom),
                tertiaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                
                stackView.bottom.constraint(equalTo: tertiaryTextLabel.safeAreaLayoutGuide.top, constant: -20.0)
            ])
        } else {
            constraints.portrait.append(contentsOf: [
                stackView.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom)
            ])
        }
        
        guard let leftContainerView, let rightContainerView else {
            return
        }
        
        let landscapeStackViewLeftConstraint: NSLayoutConstraint =
            stackView.left.constraint(greaterThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0)
        landscapeStackViewLeftConstraint.priority = .defaultLow
        let landscapeStackViewRightConstraint: NSLayoutConstraint =
            stackView.right.constraint(lessThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0)
        landscapeStackViewRightConstraint.priority = .defaultLow
        
        constraints.landscape.append(contentsOf: [
            leftContainerView.top.constraint(equalTo: subviewToAddSubviews.top),
            leftContainerView.left.constraint(equalTo: subviewToAddSubviews.left),
            leftContainerView.bottom.constraint(equalTo: subviewToAddSubviews.bottom),
            leftContainerView.right.constraint(equalTo: subviewToAddSubviews.centerX),
            
            rightContainerView.top.constraint(equalTo: subviewToAddSubviews.top),
            rightContainerView.left.constraint(equalTo: subviewToAddSubviews.centerX),
            rightContainerView.bottom.constraint(equalTo: subviewToAddSubviews.bottom),
            rightContainerView.right.constraint(equalTo: subviewToAddSubviews.right),
            
            imageView.height.constraint(equalTo: imageView.safeAreaLayoutGuide.width),
            imageView.width.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.height, multiplier: 0.66),
            imageView.centerX.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.centerX),
            imageView.centerY.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.centerY),
            
            textLabel.top.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.top, constant: 60.0),
            secondaryTextLabel.top.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottom, constant: 8.0),
            
            landscapeStackViewLeftConstraint,
            landscapeStackViewRightConstraint,
            stackView.centerX.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.centerX)
        ])
        
        let landscapeTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.textConfiguration.alignment {
        case .left:
            [
                textLabel.left.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                textLabel.left.constraint(greaterThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0),
                textLabel.centerX.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                textLabel.left.constraint(greaterThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.landscape.append(contentsOf: landscapeTextAlignmentConstraints)
        
        let landscapeSecondaryTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.secondaryConfiguration.alignment {
        case .left:
            [
                secondaryTextLabel.left.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0),
                secondaryTextLabel.centerX.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.landscape.append(contentsOf: landscapeSecondaryTextAlignmentConstraints)
        
        if let tertiaryTextLabel {
            constraints.landscape.append(contentsOf: [
                tertiaryTextLabel.left.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                tertiaryTextLabel.bottom.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.bottom, constant: -20.0),
                tertiaryTextLabel.right.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0),
                
                stackView.bottom.constraint(equalTo: tertiaryTextLabel.safeAreaLayoutGuide.top, constant: -20.0)
            ])
        } else {
            constraints.landscape.append(contentsOf: [
                stackView.bottom.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.bottom, constant: -20.0)
            ])
        }
    }
}
