//
//  ContactTableViewCell.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 9/6/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit

class ContactTableViewCell: UITableViewCell {

    var loggedInUser: User?
    var userContact: User?
    
    @IBOutlet weak var hasRespondedLabel: UILabel!
    @IBOutlet weak var timeSentLabel: UILabel!
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
        
      
        
        if userContact.name == userContact.phoneNumber {
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
        hasRespondedLabel.text = "Waiting for \(formatedPhoneNumber) to Check In"
        } else {
            hasRespondedLabel.text = "Waiting for \(userContact.name!) to Check In"
        }
        
        timeSentLabel.text = "Time Sent \(dateFormatter.stringFromDate(message.timeSent))"
        shouldRespondByLabel.text = "CheckInTime: \(dateFormatter.stringFromDate(message.timeDue))"
        // If time is due now
        if message.timeDue.timeIntervalSince1970 < NSDate().timeIntervalSince1970 {
            newMessageIcon.image = UIImage(named: "checkedInLate")
            hasRespondedLabel.text = "Time for \(userContact.name!) to CheckIn..."
            shouldRespondByLabel.textColor = .redColor()
            
        } else {
            newMessageIcon.image = UIImage(named: "checkedInPending")
            
        }
    }
    
    // Cell tells you your contact wants you to CheckIn
    func updateWithYouHaveANewMessage(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }
        if userContact.name == userContact.phoneNumber {
            let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
            hasRespondedLabel.text = "\(formatedPhoneNumber) sent you a CheckInTime"
        } else {
            hasRespondedLabel.text = "\(userContact.name!) sent you a CheckInTime"
        }
        
        if message.timeDue.timeIntervalSince1970 < NSDate().timeIntervalSince1970 {
            newMessageIcon.image = UIImage(named: "checkedInLate")
            hasRespondedLabel.text = "It's time for you to CheckIn with \(userContact.name!)"
        } else {
            newMessageIcon.image = UIImage(named: "checkedInPending")
            
        }
        
        timeSentLabel.text = ""
        shouldRespondByLabel.text = "Check In Time: \(dateFormatter.stringFromDate(message.timeDue))"
    }
    
    // Cell tells User that user's contact responded to WhereYouApp request
    func updateWithContactRespondedToRequest(message: Message) {
        guard let userContact = userContact else {
            print("User's contact was nil")
            return
        }
        
    
        
        if userContact.name == userContact.phoneNumber {
            let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
            hasRespondedLabel.text = "\(formatedPhoneNumber) Check In!"

        } else {
            hasRespondedLabel.text = "\(userContact.name!) Check In!"
        }
        
        
        shouldRespondByLabel.text = "CheckInTime: \(dateFormatter.stringFromDate(message.timeDue))"
        
        guard let timeResponded = message.timeResponded else {
            return
        }
        timeSentLabel.text = "Checked In \(dateFormatter.stringFromDate(timeResponded))"
        newMessageIcon.image = UIImage(named: "checkedIn")
        
        
    }
    
    // Cell tell user that they responded to the contacts WhereYouApp request
    func updateWithUserRespondedToContactsRequest(message: Message) {
        guard let userContact = userContact, timeResponded = message.timeResponded else {
            print("User's contact was nil")
            return
        }
     
        
        if userContact.name == userContact.phoneNumber {
            let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(userContact.phoneNumber)
            hasRespondedLabel.text = "You Checked In with \(formatedPhoneNumber)!"
            
        } else {
            
            hasRespondedLabel.text = "You Checked In with \(userContact.name!)!"

        }
        newMessageIcon.image = UIImage(named: "checkedIn")
        timeSentLabel.text = "You Checked In \(dateFormatter.stringFromDate(timeResponded))"
        shouldRespondByLabel.text = ""
        newMessageIcon.image = UIImage(named: "checkedIn")
    }
    
    
    
    
}


