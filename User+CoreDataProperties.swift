//
//  User+CoreDataProperties.swift
//  CheckInTime
//
//  Created by Patrick Ridd on 9/16/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension User {

    @NSManaged var hasAppAccount: NSNumber
    @NSManaged var imageData: NSData
    @NSManaged var name: String?
    @NSManaged var phoneNumber: String
    @NSManaged var recordName: String?
    @NSManaged var timeCreated: NSDate
    @NSManaged var messages: NSOrderedSet?

}
