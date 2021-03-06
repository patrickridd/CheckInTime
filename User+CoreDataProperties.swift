//
//  User+CoreDataProperties.swift
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

extension User {

    @NSManaged var phoneNumber: String?
    @NSManaged var name: String?
    @NSManaged var image: NSData?
    @NSManaged var messages: NSOrderedSet?
    @NSManaged var contacts: NSOrderedSet?

}
