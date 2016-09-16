//
//  Message+CoreDataProperties.swift
//  CheckInTime
//
//  Created by Patrick Ridd on 9/15/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Message {

    @NSManaged var ckRecordID: NSData?
    @NSManaged var hasBeenSeen: NSNumber?
    @NSManaged var hasResponded: NSNumber
    @NSManaged var latitude: NSNumber?
    @NSManaged var longitude: NSNumber?
    @NSManaged var recordName: String?
    @NSManaged var text: String?
    @NSManaged var timeDue: NSDate
    @NSManaged var timeResponded: NSDate?
    @NSManaged var timeSent: NSDate
    @NSManaged var senderID: String
    @NSManaged var receiver: User
    @NSManaged var sender: User

}
