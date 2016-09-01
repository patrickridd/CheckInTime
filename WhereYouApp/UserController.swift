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
    var loggedInUser: User?
    
    let moc = Stack.sharedStack.managedObjectContext
    
    var users = [User]()
    
    
    
    func createUser(name: String, phoneNumber: String, image: UIImage, completion: () -> Void) {
        
        CloudKitManager.cloudKitController.fetchLoggedInUserRecord { (record, error) in
            guard let record = record else {
                print("Not signed in to cloudkit")
                return
            
            }
        
        guard let imageData = UIImagePNGRepresentation(image) else {
            print("Cant get NSData from Image")
            return
        }
        
        let user = User(name: name, phoneNumber: phoneNumber, imageData: imageData)
        /* Create Custom User Record with a recordID made from the users phone number so we can use the phone number to fetch him/her from coredata */
        
        let recordID = CKRecordID(recordName: user.phoneNumber)
        let customUserRecord = CKRecord(recordType:"User",recordID: recordID)
        user.record = customUserRecord
        // create reference to Current User's cloudkit ID to be able to fetch Custom Record.
        let reference = CKReference(recordID: record.recordID, action: .None)
        customUserRecord["identifier"] = reference
            
        // Save Custom Record's Record ID into core data by converting it to NSData
        user.ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(customUserRecord.recordID)
            // Save Original record's record id as reference in core data.
        user.originalRecordID = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
        
        // Save user properties to cloudkit
        customUserRecord[User.nameKey] = user.name
        customUserRecord[User.phoneNumberKey] = user.phoneNumber
        customUserRecord[User.imageKey] = user.imageAsset
              
        self.loggedInUser = user
            CloudKitManager.cloudKitController.saveRecord(customUserRecord, completion: { (record, error) in
                if let error = error {
                    print("Error saving to cloudkit. Error: \(error.localizedDescription)")
                }
                self.saveContext()
                completion()
            })

        }
        
    }
    
    func checkForCoreDataUserAccount(completion: (hasAccount: Bool)-> Void) {
        
            let sortDescriptor = NSSortDescriptor(key: "timeCreated", ascending: false)
            let request = NSFetchRequest(entityName: "User")
            request.sortDescriptors = [sortDescriptor]

            guard let fetchedUsers = (try? self.moc.executeFetchRequest(request) as? [User]),
                users = fetchedUsers where users.count > 0 else {
                print("Cant find coreDataloggedInUser")
                completion(hasAccount: false)
                return
            }
            
            self.loggedInUser = users.first
            
            let contactRequest = NSFetchRequest(entityName: "User")
            
            guard let fetchedContacts = (try? self.moc.executeFetchRequest(contactRequest) as? [User]),
                contacts = fetchedContacts, loggedInUser = self.loggedInUser else {
                    print("No Users saved")
                    return
            }
            
            loggedInUser.contacts = contacts.filter({$0.phoneNumber != loggedInUser.phoneNumber})
            completion(hasAccount: true)

            
        
        
    }
    
    func fetchCoreDataUserWithNumber(recordName: String) -> User? {
        
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [recordName])
        request.predicate = predicate
        guard let fetchedUsers = (try? moc.executeFetchRequest(request) as? [User]),
            let users = fetchedUsers, user = users.first else {
                print("Couldn't fetch user")
                return nil
        }
        return user
        
    }
    
    func saveContext() {
        do{
           try moc.save()
        }catch let error as NSError {
            print("Error saving to context. Error: \(error.localizedDescription)")
        }
        
        
    }
    
    
    
    
    
    
    
    
}