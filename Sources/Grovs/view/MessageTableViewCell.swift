//
//  MessageTableViewCell.swift
//
//  grovs
//

import UIKit

/// A custom table view cell used for displaying a message with a title, subtitle, and a new message indicator.
class MessageTableViewCell: UITableViewCell {

    /// A view that indicates if the message is new.
    @IBOutlet weak var newMessageIndicatorView: UIView!

    /// A label displaying the subtitle of the message.
    @IBOutlet weak var messageSubtitleLabel: UILabel!

    /// A label displaying the title of the message.
    @IBOutlet weak var messageTitleLabel: UILabel!

    // MARK: - Accessibility

    override var accessibilityLabel: String? {
        get {
            var components = [String]()
            if let title = messageTitleLabel?.text, !title.isEmpty {
                components.append(title)
            }
            if let subtitle = messageSubtitleLabel?.text, !subtitle.isEmpty {
                components.append(subtitle)
            }
            if newMessageIndicatorView?.isHidden == false {
                components.append("Unread")
            }
            return components.joined(separator: ", ")
        }
        set { super.accessibilityLabel = newValue }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { return .button }
        set { super.accessibilityTraits = newValue }
    }
}
