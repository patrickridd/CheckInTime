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
    
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var contactName: UILabel!
    @IBOutlet weak var hasRespondedLabel: UILabel!
    @IBOutlet weak var timeResponded: UILabel!
    @IBOutlet weak var shouldRespondByLabel: UILabel!
    @IBOutlet weak var newMessageIcon: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    /// Updates View with Message Details
    func updateWith(message: Message) {
        guard let loggedInUser = UserController.sharedController.loggedInUser else {
            return
        }
        self.loggedInUser = loggedInUser
        if message.senderID == loggedInUser.phoneNumber {
            self.userContact = message.receiver
        } else {
            self.userContact = message.sender
        }
        guard let userContact = self.userContact else {
            print("No contact in MessageTableViewCell")
            return
        }
        // Set contactlabel and image to the name of the loggedInUser's contact
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
        if userContact.phoneNumber == userContact.name {
            self.contactName.text = formatedPhoneNumber
        } else {
            self.contactName.text = userContact.name ?? formatedPhoneNumber
        }
        self.profileImage.image = userContact.photo
        self.layoutIfNeeded()
        setupImage()
        // Sender is looking at message that has not been responded to
        if message.timeResponded == nil && message.sender?.phoneNumber == loggedInUser.phoneNumber {
            updateWithWaitingForReceiverResponse(message)
        }
            // Receiver is looking at message that needs to be filled out and responded to
        else if message.timeResponded == nil && message.receiver?.phoneNumber == loggedInUser.phoneNumber {
            updateWithYouHaveANewMessage(message)
        }
            
            // Contact Responded to Logged In User's request.
        else if message.timeResponded != nil && message.receiver?.phoneNumber != loggedInUser.phoneNumber{
            updateWithContactRespondedToRequest(message)
        }
            // Logged In User responded to a message request
        else if message.timeResponded != nil && message.receiver?.phoneNumber == loggedInUser.phoneNumber {
            updateWithUserRespondedToContactsRequest(message)
        }
    }
    
    
    /// Cell tells you that your request hasn't been responded to yet
    func updateWithWaitingForReceiverResponse(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
        if userContact.name == userContact.phoneNumber {
        hasRespondedLabel.textColor = UIColor ( red: 0.2078, green: 0.7294, blue: 0.7373, alpha: 1.0 )
        hasRespondedLabel.text = "You sent \(formatedPhoneNumber) a CheckInTime"
        } else {
            hasRespondedLabel.text = "You sent \(userContact.name ?? formatedPhoneNumber) a CheckInTime"
        }
        if message.timeDue.timeIntervalSince1970 < NSDate().timeIntervalSince1970 {
            newMessageIcon.image = UIImage(named: "notCheckedInPink")
            hasRespondedLabel.text = "Time for \(userContact.name ?? formatedPhoneNumber) to CheckIn..."
            hasRespondedLabel.textColor = UIColor ( red: 0.1882, green: 0.2275, blue: 0.3137, alpha: 1.0 )
        } else {
            newMessageIcon.image = UIImage(named: "checkedInPending")
        }
        timeResponded.text = ""
        shouldRespondByLabel.text = "CheckInTime: \(dateFormatter.stringFromDate(message.timeDue))"
    }
    
    /// Cell tells you your contact wants to know WhereYouApp
    func updateWithYouHaveANewMessage(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }
        timeResponded.text = ""
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
        if userContact.name == userContact.phoneNumber {
            shouldRespondByLabel.text = "CheckInTime: \(dateFormatter.stringFromDate(message.timeDue))"
            hasRespondedLabel.text = "\(formatedPhoneNumber) wants you to CheckIn"
            
            if message.timeDue.timeIntervalSince1970 < NSDate().timeIntervalSince1970 {
                newMessageIcon.image = UIImage(named: "notCheckedInPink")
                hasRespondedLabel.text = "Time for you to CheckIn with \(formatedPhoneNumber)"
            } else {
                newMessageIcon.image = UIImage(named: "checkedInPending")
            }
        } else {
            shouldRespondByLabel.text = "CheckInTime: \(dateFormatter.stringFromDate(message.timeDue))"
            hasRespondedLabel.text = "\(userContact.name ?? formatedPhoneNumber) sent you a CheckInTime"
            if message.timeDue.timeIntervalSince1970 < NSDate().timeIntervalSince1970 {
                newMessageIcon.image = UIImage(named: "notCheckedInPink")
                hasRespondedLabel.text = "Time for you to CheckIn with \(userContact.name ?? formatedPhoneNumber)"
                hasRespondedLabel.textColor = UIColor ( red: 0.1882, green: 0.2275, blue: 0.3137, alpha: 1.0 )
            } else {
                newMessageIcon.image = UIImage(named: "checkedInPending")
            }
        }
    }
    
    /// Cell tells User that user's contact responded to WhereYouApp request
    func updateWithContactRespondedToRequest(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
        if userContact.name == userContact.phoneNumber {
            hasRespondedLabel.text = formatedPhoneNumber
            hasRespondedLabel.text = "\(formatedPhoneNumber) has CheckedIn."
            
        } else {
            hasRespondedLabel.text = "\(userContact.name ?? formatedPhoneNumber) has CheckedIn."
            newMessageIcon.image = UIImage(named: "checkedIn")
        }
        guard let checkInAt = message.timeResponded else {
            return
        }
        timeResponded.text = " CheckedIn at \(dateFormatter.stringFromDate(checkInAt))"
    }
    
    
    
    /// Cell tell user that they responded to the contacts WhereYouApp request
    func updateWithUserRespondedToContactsRequest(message: Message) {
        guard let userContact = userContact, checkedInAt = message.timeResponded else {
            print("User's contact was nil")
            return
        }
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
        if userContact.name == userContact.phoneNumber{
            hasRespondedLabel.text = "You CheckedIn with \(formatedPhoneNumber)"
        } else {
            hasRespondedLabel.text = "You CheckedIn with \(userContact.name ?? formatedPhoneNumber)"
        }
        newMessageIcon.image = UIImage(named: "checkedIn")
        timeResponded.text = "You CheckedIn \(dateFormatter.stringFromDate(checkedInAt))"
        shouldRespondByLabel.text = ""
    }
    
    /// Sets up the contacts profile image. 
    func setupImage() {
        let radius = self.profileImage.frame.size.height/2
        self.profileImage?.layer.masksToBounds = true
        self.profileImage?.layer.cornerRadius = radius
        self.profileImage?.clipsToBounds = true
    }
    
    
}
