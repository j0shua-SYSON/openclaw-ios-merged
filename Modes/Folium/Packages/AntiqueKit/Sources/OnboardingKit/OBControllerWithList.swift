//
//  OBControllerWithList.swift
//  AntiqueKit
//
//  Created by Jarrod Norwell on 13/5/2026.
//

import ConstraintKit
import Foundation
import UIKit

open class OBControllerWithList : UIViewController {
    var dataSource: UICollectionViewDiffableDataSource<String, CellConfiguration>? = nil
    var snapshot: NSDiffableDataSourceSnapshot<String, CellConfiguration>? = nil
    
    var leftContainerView: UIView? = nil,
        rightContainerView: UIView? = nil
    
    var visualEffectView: UIVisualEffectView? = nil
    
    var imageView: UIImageView? = nil
    
    var textLabel: UILabel? = nil,
        secondaryTextLabel: UILabel? = nil,
        tertiaryTextLabel: UILabel? = nil
    
    var collectionView: UICollectionView? = nil
    
    var stackView: UIStackView? = nil
    
    // portrait, landscape
    var constraints: (portrait: [NSLayoutConstraint], landscape: [NSLayoutConstraint]) = ([], [])
    
    var configuration: OBControllerWithListConfiguration
    public init(configuration: OBControllerWithListConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = if #available(iOS 18.0, *), modalPresentationStyle == .overFullScreen {
            .clear
        } else {
            .systemBackground
        }
        
        if #available(iOS 18.0, *), modalPresentationStyle == .overFullScreen {
            visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            guard let visualEffectView else {
                return
            }
            visualEffectView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(visualEffectView)
            
            visualEffectView.top.constraint(equalTo: view.top).isActive = true
            visualEffectView.left.constraint(equalTo: view.left).isActive = true
            visualEffectView.bottom.constraint(equalTo: view.bottom).isActive = true
            visualEffectView.right.constraint(equalTo: view.right).isActive = true
        }
        
        let subviewToAddSubviews: UIView = visualEffectView?.contentView ?? view
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
        
        imageView = UIImageView(image: configuration.image?
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(font: configuration.textConfiguration.font)))
        guard let imageView else {
            return
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = configuration.textConfiguration.color
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
        (isPortrait ? subviewToAddSubviews : leftContainerView).addSubview(textLabel)
        
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
        (isPortrait ? subviewToAddSubviews : leftContainerView).addSubview(secondaryTextLabel)
        
        if let tertiaryConfiguration: LabelConfiguration = configuration.tertiaryConfiguration {
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
            (isPortrait ? subviewToAddSubviews : leftContainerView).addSubview(tertiaryTextLabel)
        }
        
        let mapped: [UIButton] = configuration.buttons.map { button in
            UIButton(configuration: button.configuration, primaryAction: UIAction { action in
                Task { @MainActor in
                    await button.action(self)
                }
            })
        }
        
        stackView = UIStackView(arrangedSubviews: mapped)
        guard let stackView else {
            return
        }
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 20.0
        (isPortrait ? subviewToAddSubviews : leftContainerView).addSubview(stackView)
        
        let compositionalLayoutConfiguration: UICollectionViewCompositionalLayoutConfiguration = UICollectionViewCompositionalLayoutConfiguration()
        compositionalLayoutConfiguration.interSectionSpacing = 20.0
        
        collectionView = UICollectionView(frame: .zero,
                                          collectionViewLayout: UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, layoutEnvironment in
            guard let dataSource = self.dataSource,
                  let sectionIdentifier: String = dataSource.sectionIdentifier(for: sectionIndex) else {
                return nil
            }
            
            let items: Int = dataSource.snapshot().itemIdentifiers(inSection: sectionIdentifier).count
            let itemsInRow: CGFloat = if self.iPhone {
                1.0
            } else {
                items == 1 ? 1.0 : 0.5
            }
            
            let estimatedLayoutDimension: NSCollectionLayoutDimension = NSCollectionLayoutDimension.estimated(100.0)
            let fullWidthLayoutDimension: NSCollectionLayoutDimension = NSCollectionLayoutDimension.fractionalWidth(1.0)
            let calculatedWidthLayoutDimension: NSCollectionLayoutDimension = NSCollectionLayoutDimension.fractionalWidth(itemsInRow)
            
            let item: NSCollectionLayoutItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: calculatedWidthLayoutDimension,
                                                                                                         heightDimension: estimatedLayoutDimension))
            
            let group: NSCollectionLayoutGroup = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: fullWidthLayoutDimension, heightDimension: estimatedLayoutDimension),
                                                                                    subitems: [item])
            group.interItemSpacing = NSCollectionLayoutSpacing.fixed(20.0)
            
            let section: NSCollectionLayoutSection = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 20.0
            return section
        }, configuration: compositionalLayoutConfiguration))
        guard let collectionView else {
            return
        }
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        if #available(iOS 26.0, *) {
            collectionView.cornerConfiguration = .uniformCorners(radius: .fixed(20.0))
        }
        if isPortrait {
            subviewToAddSubviews.insertSubview(collectionView, belowSubview: imageView)
        } else {
            rightContainerView.addSubview(collectionView)
        }
        
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            addConstraintsForPad()
        case .phone:
            addConstraintsForPhone()
        default:
            break
        }
        
        view.addConstraints(constraints.portrait)
        
        // MARK: Collection View Data
        let cellRegistration: UICollectionView.CellRegistration<OBListCell, CellConfiguration> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
            cell.configure(with: itemIdentifier, self.modalPresentationStyle == .overFullScreen)
        }
        
        dataSource = UICollectionViewDiffableDataSource<String, CellConfiguration>(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemIdentifier)
        }
        
        guard let dataSource else {
            return
        }
        
        snapshot = NSDiffableDataSourceSnapshot<String, CellConfiguration>()
        guard var snapshot else {
            return
        }
        snapshot.appendSections(["Section 0"])
        snapshot.appendItems(configuration.cells, toSection: "Section 0")
        Task {
            await dataSource.apply(snapshot)
        }
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in } completion: { context in
            self.changeSubviewsForOrientation(self.interfaceOrientation())
            
            switch self.interfaceOrientation() {
            case .portrait:
                self.view.removeConstraints(self.constraints.landscape)
                self.view.addConstraints(self.constraints.portrait)
            case .landscapeLeft, .landscapeRight:
                self.view.removeConstraints(self.constraints.portrait)
                self.view.addConstraints(self.constraints.landscape)
            default:
                break
            }
            
            self.view.setNeedsUpdateConstraints()
        }
    }
    
    func changeSubviewsForOrientation(_ interfaceOrientation: UIInterfaceOrientation) {
        if interfaceOrientation.isPortrait {
            guard let leftContainerView, let rightContainerView else {
                return
            }
            
            leftContainerView.subviews.forEach(\.removeFromSuperview)
            rightContainerView.subviews.forEach(\.removeFromSuperview)
            
            guard let imageView, let textLabel, let secondaryTextLabel, let collectionView, let stackView else {
                return
            }
            
            let subviewToAddSubviews: UIView = visualEffectView?.contentView ?? view
            
            subviewToAddSubviews.addSubview(imageView)
            subviewToAddSubviews.addSubview(textLabel)
            subviewToAddSubviews.addSubview(secondaryTextLabel)
            subviewToAddSubviews.addSubview(stackView)
            subviewToAddSubviews.insertSubview(collectionView, belowSubview: imageView)
            
            if let tertiaryTextLabel {
                subviewToAddSubviews.addSubview(tertiaryTextLabel)
            }
        } else {
            let subviewToAddSubviews: UIView = visualEffectView?.contentView ?? view
            
            subviewToAddSubviews.subviews.forEach(\.removeFromSuperview)
            
            guard let leftContainerView, let rightContainerView else {
                return
            }
            
            subviewToAddSubviews.addSubview(leftContainerView)
            subviewToAddSubviews.addSubview(rightContainerView)
            
            guard let imageView, let textLabel, let secondaryTextLabel, let collectionView, let stackView else {
                return
            }
            
            leftContainerView.addSubview(imageView)
            leftContainerView.addSubview(textLabel)
            leftContainerView.addSubview(secondaryTextLabel)
            leftContainerView.addSubview(stackView)
            rightContainerView.addSubview(collectionView)
            
            if let tertiaryTextLabel {
                leftContainerView.addSubview(tertiaryTextLabel)
            }
        }
    }
    
    func addConstraintsForPad() {
        guard let imageView, let textLabel, let secondaryTextLabel, let collectionView, let stackView else {
            return
        }
        
        let subviewToAddSubviews: UIView = visualEffectView?.contentView ?? view
        
        constraints.portrait.append(contentsOf: [
            imageView.top.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.top, constant: 20.0),
            
            textLabel.top.constraint(equalTo: imageView.safeAreaLayoutGuide.bottom, constant: 20.0),
            secondaryTextLabel.top.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottom, constant: 8.0),
            
            collectionView.top.constraint(equalTo: secondaryTextLabel.safeAreaLayoutGuide.bottom, constant: 20.0),
            collectionView.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
            collectionView.bottom.constraint(equalTo: stackView.safeAreaLayoutGuide.top, constant: -20.0),
            collectionView.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
            
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
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                secondaryTextLabel.centerX.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                secondaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.portrait.append(contentsOf: portraitSecondaryTextAlignmentConstraints)
        
        if let tertiaryTextLabel {
            constraints.portrait.append(contentsOf: [
                tertiaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                tertiaryTextLabel.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom),
                tertiaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                tertiaryTextLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX),
                
                stackView.bottom.constraint(equalTo: tertiaryTextLabel.safeAreaLayoutGuide.top, constant: -20.0)
            ])
        } else {
            constraints.portrait.append(contentsOf: [
                stackView.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom)
            ])
        }
        
        constraints.landscape.append(contentsOf: [
            imageView.top.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.top, constant: 20.0),
            
            textLabel.top.constraint(equalTo: imageView.safeAreaLayoutGuide.bottom, constant: 20.0),
            secondaryTextLabel.top.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottom, constant: 8.0),
            
            collectionView.top.constraint(equalTo: secondaryTextLabel.safeAreaLayoutGuide.bottom, constant: 20.0),
            collectionView.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
            collectionView.bottom.constraint(equalTo: stackView.safeAreaLayoutGuide.top, constant: -20.0),
            collectionView.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
            
            stackView.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
            stackView.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
            stackView.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
        ])
        
        let landscapeTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.textConfiguration.alignment {
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
        
        constraints.landscape.append(contentsOf: landscapeTextAlignmentConstraints)
        
        let landscapeSecondaryTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.textConfiguration.alignment {
        case .left:
            [
                secondaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                secondaryTextLabel.centerX.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                secondaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.landscape.append(contentsOf: landscapeSecondaryTextAlignmentConstraints)
        
        if let tertiaryTextLabel {
            constraints.landscape.append(contentsOf: [
                tertiaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                tertiaryTextLabel.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom),
                tertiaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                tertiaryTextLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX),
                
                stackView.bottom.constraint(equalTo: tertiaryTextLabel.safeAreaLayoutGuide.top, constant: -20.0)
            ])
        } else {
            constraints.landscape.append(contentsOf: [
                stackView.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom)
            ])
        }
    }
    
    func addConstraintsForPhone() {
        guard let imageView, let textLabel, let secondaryTextLabel, let collectionView, let stackView else {
            return
        }
        
        let subviewToAddSubviews: UIView = visualEffectView?.contentView ?? view
        
        constraints.portrait.append(contentsOf: [
            imageView.top.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.top, constant: 20.0),
            
            textLabel.top.constraint(equalTo: imageView.safeAreaLayoutGuide.bottom, constant: 20.0),
            secondaryTextLabel.top.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottom, constant: 8.0),
            
            collectionView.top.constraint(equalTo: secondaryTextLabel.safeAreaLayoutGuide.bottom, constant: 20.0),
            collectionView.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
            collectionView.bottom.constraint(equalTo: stackView.safeAreaLayoutGuide.top, constant: -20.0),
            collectionView.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
            
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
        
        let portraitSecondaryTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.secondaryConfiguration.alignment {
        case .left:
            [
                secondaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                secondaryTextLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                secondaryTextLabel.left.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.portrait.append(contentsOf: portraitSecondaryTextAlignmentConstraints)
        
        if let tertiaryTextLabel {
            constraints.portrait.append(contentsOf: [
                tertiaryTextLabel.left.constraint(greaterThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.left, constant: 20.0),
                tertiaryTextLabel.bottom.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.bottom),
                tertiaryTextLabel.right.constraint(lessThanOrEqualTo: subviewToAddSubviews.safeAreaLayoutGuide.right, constant: -20.0),
                tertiaryTextLabel.centerX.constraint(equalTo: subviewToAddSubviews.safeAreaLayoutGuide.centerX),
                
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
        
        constraints.landscape.append(contentsOf: [
            leftContainerView.top.constraint(equalTo: subviewToAddSubviews.top),
            leftContainerView.left.constraint(equalTo: subviewToAddSubviews.left),
            leftContainerView.bottom.constraint(equalTo: subviewToAddSubviews.bottom),
            leftContainerView.right.constraint(equalTo: subviewToAddSubviews.centerX),
            
            rightContainerView.top.constraint(equalTo: subviewToAddSubviews.top),
            rightContainerView.left.constraint(equalTo: subviewToAddSubviews.centerX),
            rightContainerView.bottom.constraint(equalTo: subviewToAddSubviews.bottom),
            rightContainerView.right.constraint(equalTo: subviewToAddSubviews.right),
            
            imageView.top.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.top, constant: 40.0),
            
            textLabel.top.constraint(equalTo: imageView.safeAreaLayoutGuide.bottom, constant: 20.0),
            secondaryTextLabel.top.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottom, constant: 8.0),
            
            collectionView.top.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.top, constant: 20.0),
            collectionView.left.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.left, constant: 20.0),
            collectionView.bottom.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.bottom, constant: -20.0),
            collectionView.right.constraint(equalTo: rightContainerView.safeAreaLayoutGuide.right, constant: -20.0),
            
            stackView.left.constraint(greaterThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
            stackView.right.constraint(lessThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0),
            stackView.centerX.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.centerX)
        ])
        
        let landscapeTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.textConfiguration.alignment {
        case .left:
            [
                imageView.left.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                
                textLabel.left.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                imageView.centerX.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.centerX),
                
                textLabel.left.constraint(greaterThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(lessThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0),
                textLabel.centerX.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                imageView.right.constraint(equalTo: leftContainerView
                    .safeAreaLayoutGuide.right, constant: -20.0),
                
                textLabel.left.constraint(greaterThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                textLabel.right.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.landscape.append(contentsOf: landscapeTextAlignmentConstraints)
        
        let landscapeSecondaryTextAlignmentConstraints: [NSLayoutConstraint] = switch configuration.secondaryConfiguration.alignment {
        case .left:
            [
                secondaryTextLabel.left.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        case .center:
            [
                secondaryTextLabel.left.constraint(greaterThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(lessThanOrEqualTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0),
                secondaryTextLabel.centerX.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.centerX)
            ]
        case .right:
            [
                secondaryTextLabel.left.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                secondaryTextLabel.right.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0)
            ]
        default:
            []
        }
        
        constraints.landscape.append(contentsOf: landscapeSecondaryTextAlignmentConstraints)
        
        if let tertiaryTextLabel {
            constraints.landscape.append(contentsOf: [
                tertiaryTextLabel.left.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.left, constant: 20.0),
                tertiaryTextLabel.bottom.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.bottom, constant: -20.0),
                tertiaryTextLabel.right.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.right, constant: -20.0),
                
                stackView.bottom.constraint(equalTo: tertiaryTextLabel.safeAreaLayoutGuide.top, constant: -20.0)
            ])
        } else {
            constraints.landscape.append(contentsOf: [
                stackView.bottom.constraint(equalTo: leftContainerView.safeAreaLayoutGuide.bottom, constant: -20.0)
            ])
        }
    }
}
