//
//  User+CoreDataProperties.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 9/5/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension User {

    @NSManaged var ckRecordID: NSData
    @NSManaged var imageData: NSData
    @NSManaged var name: String
    @NSManaged var originalRecordID: NSData
    @NSManaged var phoneNumber: String
    @NSManaged var recordName: String
    @NSManaged var timeCreated: NSDate
    @NSManaged var hasAppAccount: NSNumber
    @NSManaged var messages: NSSet?

}
