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
}
