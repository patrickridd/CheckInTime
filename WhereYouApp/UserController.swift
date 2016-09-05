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

let NewContactAdded = "NewContactAdded"

class UserController {
    
    static let sharedController = UserController()
    var loggedInUser: User?
    
    let moc = Stack.sharedStack.managedObjectContext
    
    
    
    var contacts: [User] = [] {
        didSet {
            let nc = NSNotificationCenter.defaultCenter()
            nc.postNotificationName(NewContactAdded, object: nil)
        }
    }
    
    
    
    
    
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
            
            user.recordName = record.recordID.recordName
            let recordID = CKRecordID(recordName: user.phoneNumber)
            let customUserRecord = CKRecord(recordType:"User",recordID: recordID)
            
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
                user.hasAppAccount = true
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
        
        // Subscribe to Message Changes.
        CloudKitManager.cloudKitController.fetchSubscription("My Messages") { (subscription, error) in
            guard let _ = subscription else {
                print("Trying to subscribe to My Messages")
                MessageController.sharedController.subscribeToMessages()
                return
            }
            print("You are subscribed to received messages)")
        }
        
        self.fetchContactsFromCoreData { (contacts) in
            self.loggedInUser?.contacts = contacts
            self.contacts = contacts
            self.checkIfContactsHaveSignedUpForApp(contacts)
            completion(hasAccount: true)
            
        }
    }
    
    // Fetches all users in core data except the Logged In User
    func fetchContactsFromCoreData(completion: (contacts: [User]) -> Void) {
        let contactRequest = NSFetchRequest(entityName: "User")
        
        guard let fetchedContacts = (try? self.moc.executeFetchRequest(contactRequest) as? [User]),
            users = fetchedContacts, loggedInUser = self.loggedInUser else {
                print("No Users saved")
                return
        }
        let contacts = users.filter({$0.phoneNumber != loggedInUser.phoneNumber})
        completion(contacts: contacts)
        
    }
    
    // Check by user phone number if contacts who didn't have account now do have an account with the app.
    func checkIfContactsHaveSignedUpForApp(contacts: [User]) {
        
        
        
    }
    
    // Fetches One User from CoreData by using their phone number //
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
    
    // Fetches the loggedInUsers Contacts From Cloudkit in they get deleted. //
    func fetchCloudKitContacts(completion: (hasUsers: Bool)->Void) {
        guard let loggedInUser = loggedInUser else {
            print("No user logged in yet")
            return
        }
        
        guard let record = loggedInUser.record,
            references = record[User.contactsKey] as? [CKReference] else {
                completion(hasUsers: false)
                return
        }
        
        loggedInUser.contactReferences = references
        
        let predicate = NSPredicate(format: "recordID IN %@", argumentArray: [references])
        
        
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            if let user = User(record: record) {
                loggedInUser.contacts.append(user)
                UserController.sharedController.contacts.append(user)
            }
            
        }) { (records, error) in
            if let error = error {
                print("Error fetching contacts: Error: \(error.localizedDescription)")
                completion(hasUsers: false)
                return
            }
            completion(hasUsers: true)
            
        }
        
    }
    
    func checkIfContactHasAccount(newContact: User, completion: (record: CKRecord?) -> Void) {
        
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [newContact.phoneNumber])
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            
            }, completion: { (records, error) in
                
                guard let records = records else  {
                    print("Couldn't find User Account with contact phone number")
                    completion(record: nil)
                    return
                }
                
                completion(record: records.first)
                
                
        })
    }
    
    // Saves the ManagedObject Context
    
    func saveContext() {
        do{
            try moc.save()
        }catch let error as NSError {
            print("Error saving to context. Error: \(error.localizedDescription)")
        }
        
        
    }
    
    
    
    
    
    
    
    
}