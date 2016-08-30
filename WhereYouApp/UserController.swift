//
//  UserController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class UserController {
    
    static let sharedController = UserController()
    var user: User?
    
    let moc = Stack.sharedStack.managedObjectContext
    
    
    
    
    
    func createUser(name: String, phoneNumber: String, image: UIImage) {
        
        guard let imageData = UIImagePNGRepresentation(image) else {
            print("Cant get NSData from Image")
            return
        }
        
        let user = User(name: name, phoneNumber: phoneNumber, imageData: imageData)
        
        self.user = user
        saveContext()
    }
    
    init() {
        let request = NSFetchRequest(entityName: "User")
        
        guard let users = (try? moc.executeFetchRequest(request) as? [User]),
            user = users?.first else {
            print("No Users saved")
            return
        }
        
        self.user = user
        
    }
    
    
    
    func saveContext() {
        do{
           try moc.save()
        }catch let error as NSError {
            print("Error saving to context. Error: \(error.localizedDescription)")
        }
        
        
    }
    
    
    
    
    
    
    
    
}