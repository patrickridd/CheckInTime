//
//  MessageTableViewCell.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit

class MessageTableViewCell: UITableViewCell {
    
    var loggedInUser: User?
    var userContact: User?
    
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

        
        // Updates View with Message Details
        func updateWith(message: Message) {
            guard let user = UserController.sharedController.loggedInUser else {
                return
            }
            self.loggedInUser = user
            if message.sender.phoneNumber == user.phoneNumber {
                self.userContact = message.receiver
            } else {
                self.userContact = message.sender
            }
            
        
            // Set contactlabel and image to the name of the loggedInUser's contact
            self.contactName.text = userContact?.name
            self.profileImage.image = userContact?.photo
            
            // Sender is looking at message that has not been responded to
            if message.timeResponded == nil && message.sender.phoneNumber == loggedInUser?.phoneNumber {
                updateWithWaitingForReceiverResponse(message)
            }
                // Receiver is looking at message that needs to be filled out and responded to
            else if message.timeResponded == nil && message.receiver.phoneNumber == loggedInUser?.phoneNumber {
                updateWithYouHaveANewMessage(message)
            }
            
                // Contact Responded to Logged In User's request.
            else if message.timeResponded != nil && message.receiver.phoneNumber != loggedInUser?.phoneNumber{
                updateWithContactRespondedToRequest(message)
            }
                // Logged In User responded to a message request
            else if message.timeResponded != nil && message.receiver.phoneNumber == loggedInUser?.phoneNumber {
                updateWithUserRespondedToContactsRequest(message)
            }
            
        }
        
        
    // Cell tells you that your request hasn't been responded to yet
    func updateWithWaitingForReceiverResponse(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }

        hasRespondedLabel.text = "Waiting for \(userContact.name)'s Response"
        timeMessageSentLabel.text = "Time Sent \(dateFormatter.stringFromDate(message.timeSent))"
        shouldRespondByLabel.text = "Should respond by \(dateFormatter.stringFromDate(message.timeDue))"
        
    }

    // Cell tells you your contact wants to know WhereYouApp
    func updateWithYouHaveANewMessage(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }
        hasRespondedLabel.text = "\(userContact.name) wants to know WhereYouApp"
        timeMessageSentLabel.text = ""
        shouldRespondByLabel.text = "\(userContact.name) wants to know by \(dateFormatter.stringFromDate(message.timeDue))"
    }
    
    // Cell tells User that user's contact responded to WhereYouApp request
    func updateWithContactRespondedToRequest(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }
        hasRespondedLabel.text = "\(userContact.name) responded to WhereYouApp request"
        shouldRespondByLabel.text = ""

        guard let timeResponded = message.timeResponded else {
            return
        }
        timeMessageSentLabel.text = "Responded \(dateFormatter.stringFromDate(timeResponded))"
        
    }
    
    // Cell tell user that they responded to the contacts WhereYouApp request
    func updateWithUserRespondedToContactsRequest(message: Message) {
        guard let userContact = userContact, timeResponded = message.timeResponded else {
            print("User's contact was nil")
            return
        }
        
        hasRespondedLabel.text = "You let \(userContact.name) know WhereYouApp"
        timeMessageSentLabel.text = "You responded at \(dateFormatter.stringFromDate(timeResponded))"
        shouldRespondByLabel.text = ""
    }

    
}
