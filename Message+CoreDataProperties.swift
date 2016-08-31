//
//  Message+CoreDataProperties.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Message {

    @NSManaged var hasResponded: NSNumber?
    @NSManaged var latitude: NSNumber?
    @NSManaged var longitude: NSNumber?
    @NSManaged var text: String?
    @NSManaged var timeDue: NSDate
    @NSManaged var timeResponded: NSDate?
    @NSManaged var timeSent: NSDate
    @NSManaged var senderID: String
    @NSManaged var receiverID: String
    @NSManaged var users: NSOrderedSet?

}
