//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


import UIKit
import Cartography


@objc enum ConversationListButtonType: UInt {
    case contacts, archive, settings
}

@objc protocol ConversationListBottomBarControllerDelegate: class {
    func conversationListBottomBar(_ bar: ConversationListBottomBarController, didTapButtonWithType buttonType: ConversationListButtonType)
}


@objc final class ConversationListBottomBarController: UIViewController {
    
    weak var delegate: ConversationListBottomBarControllerDelegate?
    
    let contactsButton = IconButton()
    let settingsButton = IconButton()
    let archivedButton = IconButton()
    let contactsButtonContainer = UIView()
    let settingsButtonContainer = UIView()
    let archivedButtonContainer = UIView()
    let separator = UIView()
    let indicator = UIView()
    let contactsButtonTitle = "bottom_bar.contacts_button.title".localized.uppercased()
    let heightConstant: CGFloat = 56
    let user: ZMUser?
    
    var userObserverToken: ZMUserObserverOpaqueToken?
    var accentColorHandler: AccentColorChangeHandler?
    
    var showArchived: Bool = false {
        didSet {
            updateArchivedVisibility()
        }
    }
    
    var showSeparator: Bool {
        set { separator.fadeAndHide(!newValue) }
        get { return !separator.isHidden }
    }
    
    var showIndicator: Bool {
        set { indicator.fadeAndHide(!newValue) }
        get { return !indicator.isHidden }
    }
    
    var showTooltip: Bool = false {
        didSet {
            if self.showTooltip {
                self.contactsButton.setIconColor(UIColor.accent(), for: .normal)
            }
            else {
                self.contactsButton.setIconColor(UIColor.clear, for: UIControlState())
            }
        }
    }
    
    required init(delegate: ConversationListBottomBarControllerDelegate? = nil, user: ZMUser?) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
        self.delegate = delegate
        createViews()
        createConstraints()
        updateIndicator()
        if let user = user {
            userObserverToken = ZMUser.add(self, forUsers: [user], in: .shared())
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        ZMUser.removeObserver(for: userObserverToken)
        accentColorHandler = nil
    }
    
    fileprivate func createViews() {
        contactsButton.setTitle(contactsButtonTitle, for: UIControlState())
        contactsButton.setIcon(.contactsCircle, with: .actionButton, for: UIControlState(), renderingMode: .alwaysOriginal)
        contactsButton.setIconColor(UIColor.clear, for: UIControlState())
        contactsButton.titleImageSpacing = 18
        contactsButton.adjustsTitleWhenHighlighted = true
        contactsButton.addTarget(self, action: #selector(ConversationListBottomBarController.contactsButtonTapped(_:)), for: .touchUpInside)
        contactsButton.accessibilityIdentifier = "bottomBarContactsButton"
        
        archivedButton.setIcon(.archive, with: .tiny, for: UIControlState())
        archivedButton.addTarget(self, action: #selector(ConversationListBottomBarController.archivedButtonTapped(_:)), for: .touchUpInside)
        archivedButton.accessibilityIdentifier = "bottomBarArchivedButton"
        
        settingsButton.setIcon(.gear, with: .tiny, for: UIControlState())
        settingsButton.addTarget(self, action: #selector(ConversationListBottomBarController.settingsButtonTapped(_:)), for: .touchUpInside)
        settingsButton.accessibilityIdentifier = "bottomBarSettingsButton"

        contactsButtonContainer.addSubview(contactsButton)
        archivedButtonContainer.addSubview(archivedButton)
        [indicator, separator, archivedButton].forEach { $0.isHidden = true }
        [settingsButton, indicator].forEach(settingsButtonContainer.addSubview)
        [settingsButtonContainer, contactsButtonContainer, archivedButtonContainer, separator].forEach(view.addSubview)
        
        accentColorHandler = AccentColorChangeHandler.addObserver(self) { [weak self] color, _ in
            if let `self` = self , self.showTooltip {
                self.contactsButton.setIconColor(color, for: .normal)
            }
        }
    }
    
    fileprivate func createConstraints() {
        constrain(view, contactsButton, separator) { view, contactsButton, separator in
            view.height == heightConstant ~ 750
            
            separator.height == 0.5
            separator.left == view.left
            separator.right == view.right
            separator.top == view.top
        }
        
        constrain(view, contactsButtonContainer, contactsButton) { view, container, contactsButton in
            container.left == view.left
            container.top == view.top
            container.bottom == view.bottom
            
            contactsButton.left == container.left + 18
            contactsButton.right == container.right - 18
            contactsButton.centerY == container.centerY
        }
        
        constrain(view, archivedButtonContainer, archivedButton) { view, container, archivedButton in
            container.center == view.center
            container.top == view.top
            container.bottom == view.bottom
            
            archivedButton.left == container.left + 18
            archivedButton.right == container.right - 18
            archivedButton.centerY == container.centerY
        }
        
        constrain(view, settingsButtonContainer, settingsButton) { view, container, settingsButton in
            container.right == view.right
            container.top == view.top
            container.bottom == view.bottom
            
            settingsButton.right == container.right - 24
            settingsButton.left == container.left + 24
            settingsButton.centerY == container.centerY
        }
        
        guard let settingsImageView = settingsButton.imageView else {
            fatalError("No imageView on settingsbutton despite we just assigned an icon")
        }
        
        constrain(indicator, settingsImageView) { indicator, imageView in
            indicator.top == imageView.top - 3
            indicator.right == imageView.right + 3
            indicator.width == 8
            indicator.height == 8
        }
    }
    
    func updateArchivedVisibility() {
        contactsButton.setTitle(showArchived ? nil : contactsButtonTitle, for: UIControlState())
        archivedButton.isHidden = !showArchived
    }
    
    func updateIndicator() {
        guard let user = user else {
            showIndicator = false
            return
        }
        showIndicator = user.clientsRequiringUserAttention.count > 0
    }
    
    // MARK: - Target Action
    
    func contactsButtonTapped(_ sender: IconButton) {
        delegate?.conversationListBottomBar(self, didTapButtonWithType: .contacts)
    }
    
    func settingsButtonTapped(_ sender: IconButton) {
        delegate?.conversationListBottomBar(self, didTapButtonWithType: .settings)
    }
    
    func archivedButtonTapped(_ sender: IconButton) {
        delegate?.conversationListBottomBar(self, didTapButtonWithType: .archive)
    }
    
}

// MARK: - User Observer

extension ConversationListBottomBarController: ZMUserObserver {
    func userDidChange(_ note: UserChangeInfo!) {
        guard note.trustLevelChanged || note.clientsChanged else { return }
        updateIndicator()
    }
}

// MARK: - Helper

public extension UIView {
    func fadeAndHide(_ hide: Bool, duration: TimeInterval = 0.2, options: UIViewAnimationOptions = UIViewAnimationOptions()) {
        if !hide {
            alpha = 0
            isHidden = false
        }
        
        let animations = { self.alpha = hide ? 0 : 1 }
        let completion: (Bool) -> Void = { _ in self.isHidden = hide }
        UIView.animate(withDuration: duration, delay: 0, options: UIViewAnimationOptions(), animations: animations, completion: completion)
    }
}

