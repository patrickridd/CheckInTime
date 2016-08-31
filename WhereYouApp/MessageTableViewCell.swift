//
//  MessageTableViewCell.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit

class MessageTableViewCell: UITableViewCell {

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var contactName: UILabel!
    @IBOutlet weak var hasRespondedLabel: UILabel!
    @IBOutlet weak var timeMessageSentLabel: UILabel!
    @IBOutlet weak var shouldRespondByLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
        let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    func updateWith(message: Message) {
//        guard let sender = message.sender,
//            receiver = message.receiver,
                guard let user = UserController.sharedController.user else {
                return
        }
    
        
        
        if message.sender.phoneNumber == user.phoneNumber {
            contactName.text = message.receiver.name
            self.profileImage.image = message.receiver.photo
        } else {
            contactName.text = message.sender.name
            self.profileImage.image = message.sender.photo
        }
        
        // If message hasn't been responded to...
        if message.hasResponded == 0 {
            hasRespondedLabel.text = "Waiting for Response"
            timeMessageSentLabel.text = "Time Sent \(dateFormatter.stringFromDate(message.timeSent))"
            if message.timeDue == message.timeSent {
                shouldRespondByLabel.text = ""
            } else {
                shouldRespondByLabel.text = "Should respond by \(dateFormatter.stringFromDate(message.timeDue))"
            }
        } else {
            if let text = contactName.text {
                hasRespondedLabel.text = " \(text) has responded"
            }
        }
        
        
    }

}
