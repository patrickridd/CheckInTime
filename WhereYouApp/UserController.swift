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
import CloudKit

class UserController {
    
    static let sharedController = UserController()
    var user: User?
    
    let moc = Stack.sharedStack.managedObjectContext
    
    
    
    
    
    func createUser(name: String, phoneNumber: String, image: UIImage) {
        
        CloudKitManager.cloudKitController.fetchLoggedInUserRecord { (record, error) in
            guard let record = record else {
                return
            }
        
        guard let imageData = UIImagePNGRepresentation(image) else {
            print("Cant get NSData from Image")
            return
        }
        
        let user = User(name: name, phoneNumber: phoneNumber, imageData: imageData)
        let customUserRecord = CKRecord(recordType:"User")
        let reference = CKReference(recordID: record.recordID, action: .None)
        customUserRecord["identifier"] = reference
        customUserRecord[User.nameKey] = user.name
        customUserRecord[User.phoneNumberKey] = user.phoneNumber
        
        customUserRecord[User.imageKey] = user.imageAsset
            
        self.user = user

        }
        
        saveContext()
    }
    
    init() {
        let request = NSFetchRequest(entityName: "User")
        request.predicate = NSPredicate(format: "recordID == %@", argumentArray: [])
        
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