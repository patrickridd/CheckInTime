//
//  Message.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import CoreData


class Message: NSManagedObject {

// Insert code here to add functionality to your managed object subclass
    convenience init(text: String, latitude: Double, longitude: Double, timeSent: NSDate, timeDue: NSDate?, hasResponded: Bool, timeResponded: NSDate?, receiver: User, sender: User, context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Message", inManagedObjectContext: context)
        
        self.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        self.text = text
        self.latitude = latitude
        self.longitude = longitude
        self.timeDue = timeDue
        self.timeSent = timeSent
        self.hasResponded = hasResponded
        self.timeResponded = timeResponded
        self.receiver = receiver
        self.sender = sender
    
        
    
    }
    
    
}
