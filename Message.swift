//
//  Message.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class Message: NSManagedObject {
    
    static let recordType = "Message"
    static let textKey = "text"
    static let latitudeKey = "latitude"
    static let longitudeKey = "longitude"
    static let timeDueKey = "timeDue"
    static let timeSentKey = "timeSent"
    static let hasRespondedKey = "hasResponded"
    static let timeRespondedKey = "timeResponded"
    static let receiverIDKey = "receiverID"
    static let senderIDKey = "senderID"
    static let users = "users"
    
    var record: CKRecord?
    
// Insert code here to add functionality to your managed object subclass
    convenience init(text: String? = nil, latitude: Double? = nil, longitude: Double? = nil, timeSent: NSDate = NSDate(), timeDue: NSDate, hasResponded: Bool = false, timeResponded: NSDate? = nil, sender: User, receiver : User, context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Message", inManagedObjectContext: context)!
        
        self.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.text = text
        self.latitude = latitude
        self.longitude = longitude
        self.timeDue = timeDue
        self.timeSent = timeSent
        self.hasResponded = hasResponded
        self.timeResponded = timeResponded
        self.sender = sender
        self.receiver = receiver
               
        
    }
    
    
    convenience init?(record: CKRecord) {
        guard let timeDue = record[Message.timeDueKey] as? NSDate,
            timeSent = record[Message.timeSentKey] as? NSDate,
            hasResponded = record[Message.hasRespondedKey] as? Int,
            senderID = record[Message.senderIDKey] as? String,
            receiverID = record[Message.receiverIDKey] as? String else {
                return nil
        }
        let context = Stack.sharedStack.managedObjectContext
        let entity = NSEntityDescription.entityForName("Message", inManagedObjectContext: context)!
        
        self.init(entity: entity, insertIntoManagedObjectContext: context)

       
        self.timeDue = timeDue
        self.timeSent = timeSent
        self.hasResponded = hasResponded
        self.ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
        
        
        
        guard let fetchedSender = UserController.sharedController.fetchCoreDataUserWithNumber(senderID), fetchedReceiver = UserController.sharedController.fetchCoreDataUserWithNumber(receiverID) else {
            return nil
        }
        self.sender = fetchedSender
        self.receiver = fetchedReceiver
        
        // Only Apply for the when the receiver responds.
        guard let text = record[Message.textKey] as? String,
        latitude = record[Message.latitudeKey] as? Double,
        longitude = record[Message.longitudeKey] as? Double,
        timeResponded = record[Message.timeRespondedKey] as? NSDate  else {
            return
        }
        
        self.text = text
        self.longitude = longitude
        self.latitude = latitude
        self.timeResponded = timeResponded

        
        
    }
    
    
}
