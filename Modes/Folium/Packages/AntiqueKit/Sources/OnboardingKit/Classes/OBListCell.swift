//
//  OBListCell.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 13/5/2026.
//

import ConstraintKit
import UIKit

class OBListCell : UICollectionViewCell {
    var visualEffectView: UIVisualEffectView? = nil
    
    var imageView: UIImageView? = nil
    
    var textLabel: UILabel? = nil,
        secondaryTextLabel: UILabel? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        if #available(iOS 26.0, *) {
            backgroundColor = .clear
            cornerConfiguration = .uniformCorners(radius: .fixed(24.0))
        }
        
        if #available(iOS 26.0, *) {
            visualEffectView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            guard let visualEffectView else {
                return
            }
            visualEffectView.translatesAutoresizingMaskIntoConstraints = false
            visualEffectView.cornerConfiguration = .uniformCorners(radius: .fixed(24.0))
            addSubview(visualEffectView)
            sendSubviewToBack(visualEffectView)
            
            visualEffectView.top.constraint(equalTo: safeAreaLayoutGuide.top).isActive = true
            visualEffectView.left.constraint(equalTo: safeAreaLayoutGuide.left).isActive = true
            visualEffectView.bottom.constraint(equalTo: safeAreaLayoutGuide.bottom).isActive = true
            visualEffectView.right.constraint(equalTo: safeAreaLayoutGuide.right).isActive = true
        }
        
        imageView = UIImageView()
        guard let imageView else {
            return
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        
        textLabel = UILabel()
        guard let textLabel else {
            return
        }
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.numberOfLines = 1
        contentView.addSubview(textLabel)
        
        secondaryTextLabel = UILabel()
        guard let secondaryTextLabel else {
            return
        }
        secondaryTextLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryTextLabel.numberOfLines = 5
        contentView.addSubview(secondaryTextLabel)
        
        contentView.addConstraints([
            imageView.top.constraint(equalTo: contentView.salg.top, constant: 20.0),
            imageView.left.constraint(equalTo: contentView.salg.left, constant: 20.0),
            imageView.width.constraint(equalToConstant: 24.0),
            imageView.height.constraint(equalTo: imageView.salg.widthAnchor),
            
            textLabel.top.constraint(equalTo: contentView.salg.top, constant: 20.0),
            textLabel.left.constraint(equalTo: imageView.salg.right, constant: 20.0),
            textLabel.right.constraint(lessThanOrEqualTo: contentView.salg.right, constant: -20.0),
            
            secondaryTextLabel.top.constraint(equalTo: textLabel.salg.bottom, constant: 8.0),
            secondaryTextLabel.left.constraint(equalTo: imageView.salg.right, constant: 20.0),
            secondaryTextLabel.bottom.constraint(equalTo: contentView.salg.bottom, constant: -20.0),
            secondaryTextLabel.right.constraint(lessThanOrEqualTo: contentView.salg.right, constant: -20.0),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with configuration: CellConfiguration, _ overFullScreen: Bool) {
        guard let imageView, let textLabel, let secondaryTextLabel else {
            return
        }
        
        if !overFullScreen {
            if #available(iOS 26.0, *) {
                guard let visualEffectView else {
                    return
                }
                
                visualEffectView.isHidden = true
            }
            
            backgroundColor = .secondarySystemBackground
            if #available(iOS 26.0, *) {
                cornerConfiguration = .uniformCorners(radius: .fixed(24.0))
            } else {
                layer.cornerCurve = .continuous
                layer.cornerRadius = 24.0
            }
        }
        
        imageView.image = configuration.image?
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(font: configuration.labels.primary.font))
        
        textLabel.font = configuration.labels.primary.font
        if let attributedText: AttributedString = configuration.labels.primary.attributedText {
            textLabel.attributedText = NSAttributedString(attributedText)
        } else {
            textLabel.text = configuration.labels.primary.text
        }
        textLabel.textAlignment = configuration.labels.primary.alignment
        textLabel.textColor = configuration.labels.primary.color
        
        secondaryTextLabel.font = configuration.labels.secondary.font
        if let attributedText: AttributedString = configuration.labels.secondary.attributedText {
            secondaryTextLabel.attributedText = NSAttributedString(attributedText)
        } else {
            secondaryTextLabel.text = configuration.labels.secondary.text
        }
        secondaryTextLabel.textAlignment = configuration.labels.secondary.alignment
        secondaryTextLabel.textColor = configuration.labels.secondary.color
    }
}
