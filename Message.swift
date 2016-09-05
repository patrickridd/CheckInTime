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
    
    
    //////////////////////////////////////////////////////
    //////////////////// Static Keys /////////////////////
    //////////////////////////////////////////////////////
    
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
    
    // Stored Properties not found in CoreDataModel
    var record: CKRecord?
    var senderID: String?
    
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
        self.senderID = sender.phoneNumber
               
        
    }
    
    
    
    
//////////////////////////////////////////////////////
//////////// Cloudkit Properties /////////////////////
//////////////////////////////////////////////////////

    
    // Message Record 
    var cloudKitRecord: CKRecord? {
        guard let data = self.ckRecordID else {
            return nil
        }
        let recordID = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! CKRecordID
        self.ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(recordID)

        return CKRecord(recordType: Message.recordType, recordID: recordID)
    }
    
    // Message CKReference
    var cloudKitReference: CKReference? {
        guard let data = self.ckRecordID else {
                return nil
        }
        guard let recordID =  NSKeyedUnarchiver.unarchiveObjectWithData(data) as? CKRecordID else {
            return nil
        }
        self.ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(recordID)
        
        let reference = CKReference(recordID: recordID, action: .DeleteSelf)
        return reference
    }
    
    
    
//////////////////////////////////////////////////////
//////////// CloudKit Failable Initializer ///////////
//////////////////////////////////////////////////////

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
        self.recordName = record.recordID.recordName

        
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
