//
//  User.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import CoreData
import UIKit


class User: NSManagedObject {

// Insert code here to add functionality to your managed object subclass
    convenience init(name: String , phoneNumber: String, imageData: NSData, insertIntoManagedObjectContext context: NSManagedObjectContext = Stack.sharedStack.managedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("User", inManagedObjectContext: context)
        self.init(entity: entity!, insertIntoManagedObjectContext: context)
        self.name = name
        self.phoneNumber = phoneNumber
        self.imageData = imageData
        
    }
    
    var photo: UIImage {
           guard let image = UIImage(data: imageData) else {
                if let profileImage = UIImage(named: "profile") {
                    return profileImage
                }
                return UIImage()
        }
        
        return image
    }
    
    
}
