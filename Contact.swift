//
//  Contact.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Contact: NSManagedObject {
    
    // Insert code here to add functionality to your managed object subclass
    convenience init(name: String, phoneNumber: String, imageData: NSData, context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Contact", inManagedObjectContext: context)
        self.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        self.name = name
        self.phoneNumber = phoneNumber
        self.imageData = imageData
        
        //self.sharedMessages = sharedMessages
        
    }
    
    var photo: UIImage {
        guard  let image = UIImage(data: self.imageData) else {
            return UIImage(named:"profile")!
        }
        return image
    }
    
    
}
