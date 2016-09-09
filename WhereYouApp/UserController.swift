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
            
            let user = User(name: name, phoneNumber: phoneNumber, imageData: imageData, hasAppAccount: true)
            /* Create Custom User Record with a recordID made from the users phone number so we can use the phone number to fetch him/her from coredata */
            
            user.recordName = record.recordID.recordName
            let recordID = CKRecordID(recordName: user.phoneNumber)
            let customUserRecord = CKRecord(recordType:"User",recordID: recordID)
            user.cloudKitRecord = customUserRecord
            
            // create reference to Current User's cloudkit ID to be able to fetch Custom Record.
            let reference = CKReference(recordID: record.recordID, action: .None)
            customUserRecord["identifier"] = reference
            
            // Save Custom Record's Record ID into core data by converting it to NSData
            user.ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(customUserRecord.recordID)
            // Save Original record's record id as reference in core data.
            user.originalRecordID = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
            
            // Save user properties to cloudkit
            customUserRecord[User.nameKey] = user.name ?? user.phoneNumber
            customUserRecord[User.phoneNumberKey] = user.phoneNumber
            customUserRecord[User.imageKey] = user.imageAsset
            self.loggedInUser = user
            CloudKitManager.cloudKitController.saveRecord(customUserRecord, completion: { (record, error) in
                if let error = error {
                    print("Error saving to cloudkit. Error: \(error.localizedDescription)")
                }
                user.hasAppAccount = 1
                MessageController.sharedController.subscribeToMessages()
                self.saveContext()
                completion()
            })
            
        }
        
    }
    
    func checkForCoreDataUserAccount(completion: (hasAccount: Bool)-> Void) {
        
        let sortDescriptor = NSSortDescriptor(key: "timeCreated", ascending: true)
        let request = NSFetchRequest(entityName: "User")
        request.sortDescriptors = [sortDescriptor]
        
        guard let fetchedUsers = (try? self.moc.executeFetchRequest(request) as? [User]),
            users = fetchedUsers where users.count > 0 else {
                print("Cant find coreDataloggedInUser")
                completion(hasAccount: false)
                return
        }
        
        self.loggedInUser = users.first
        guard let loggedInUser = self.loggedInUser else {
            print("No user")
            completion(hasAccount: false)
            return
        }
        self.fetchContactsFromCoreData { (contacts) in
            self.loggedInUser?.contacts = contacts
            self.contacts = contacts
            
            self.fetchUsersCloudKitRecord(self.loggedInUser!, completion: { (record) in
                // Subscribe to Message Changes.
                // MessageController.sharedController.fetchUnsyncedMessagesFromCloudKitToCoreData(loggedInUser)
                
                CloudKitManager.cloudKitController.fetchSubscription("My Messages") { (subscription, error) in
                    guard let _ = subscription else {
                        print("Trying to subscribe to My Messages")
                        MessageController.sharedController.subscribeToMessages()
                        return
                    }
                    print("You are subscribed to received messages")
                }
                completion(hasAccount: true)
                
            })
            
        }
    }
    
    // Adds contact to Contacts and then orders the contacts with the new Contact alphabetically.
    func addContactAndOrderList(contact: User) {
        var contactList = UserController.sharedController.contacts
        contactList.append(contact)
        
        let orderedList = contactList.sort{$0.0.name < $0.1.name}
        UserController.sharedController.contacts = orderedList
        
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
        let contactsInOrder = contacts.sort{$0.0.name < $0.1.name}
        completion(contacts: contactsInOrder)
        
    }
    
    // Check by user phone number if contacts who didn't have account now do have an account with the app.
    func checkIfContactsHaveSignedUpForApp(completion: (newAppAcctUsers: Bool, updatedUsers: [User]?)->Void) {
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "hasAppAccount == 0")
        request.predicate = predicate
        
        guard let users = (try? moc.executeFetchRequest(request) as! [User]) else {
            return
        }
        if users.count < 1 {
            print("No users to Check for App status")
            completion(newAppAcctUsers: false, updatedUsers: nil)
            return
        }
        let phoneNumbers = users.flatMap({$0.phoneNumber})
        let cloudPredicate = NSPredicate(format: "phoneNumber IN %@", argumentArray: [phoneNumbers])
        
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: cloudPredicate, recordFetchedBlock: { (record) in
            
        }) { (records, error) in
            guard let records = records else {
                print("reords are nil")
                completion(newAppAcctUsers: false, updatedUsers: nil)
                return
            }
            let newUsers = records.flatMap({User(record: $0)})
            
            if newUsers.count < 1 {
                completion(newAppAcctUsers: false, updatedUsers: nil)
                return
            }
            var updatedUsers: [User] = []
            
            for user in users {
                let newUser = newUsers.filter{$0.phoneNumber == user.phoneNumber}
                if newUser.count > 0 {
                    self.updateContactsAppStatus(user, completion: { (wasSaved) in
                        if wasSaved {
                            updatedUsers.append(user)
                        }
                    })
                }
            }
            
            self.deleteContactsFromCoreData(newUsers)
            completion(newAppAcctUsers: true, updatedUsers: updatedUsers)
        }
        
        
    }
    
    func checkIfUsersHaveDeletedApp(completion: (haveDeletedApp: Bool, updatedUsers: [User]?) -> Void) {
        guard let loggedInUser = loggedInUser else {
            return
        }
        
        // Fetch all users who have app AND isn't the logged in user.
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "hasAppAccount == 1")
        let predicateUser = NSPredicate(format: "phoneNumber != %@", argumentArray: [loggedInUser.phoneNumber])
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, predicateUser])
        request.predicate = compoundPredicate
        
        guard var users = (try? moc.executeFetchRequest(request) as! [User]) else {
            completion(haveDeletedApp: false, updatedUsers: nil)
            return
        }
        // If no users have app in contacts return false to users having deleted app.
        if users.count < 1 {
            print("No users to Check for App status")
            completion(haveDeletedApp: false, updatedUsers: nil)
            return
        }
        
        // Fetch records of all user's contacts who have app
        let phoneNumbers = users.flatMap({$0.phoneNumber})
        let cloudPredicate = NSPredicate(format: "phoneNumber IN %@", argumentArray: [phoneNumbers])
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: cloudPredicate, recordFetchedBlock: { (record) in
            
        }) { (records, error) in
            if records?.count < 1 {
                completion(haveDeletedApp: true, updatedUsers: users)
                return
            }
            guard let records = records else {
                completion(haveDeletedApp: true, updatedUsers: users)
                return
            }
            
            let usersWhoHaveRecords = records.flatMap({User(record: $0)})
            for user in users {
                let userStillHasApp = usersWhoHaveRecords.filter{$0.phoneNumber == user.phoneNumber}
                if let userStillHasApp = userStillHasApp.first {
                    if let index = users.indexOf(userStillHasApp) {
                        users.removeAtIndex(index)
                    }
                }
            }
            if users.count < 1 {
                completion(haveDeletedApp: false, updatedUsers: nil)
            } else {
                completion(haveDeletedApp: true, updatedUsers: users)
            }
        }
    }
    
    func fetchUsersCloudKitRecord(user: User, completion: (record: CKRecord?) ->Void) {
        
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [user.phoneNumber])
        
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            
        }) { (records, error) in
            guard let records = records,
                record = records.first else {
                    print("No record found for user in cloudkit")
                    completion(record: nil)
                    return
            }
            user.cloudKitRecord = record
            completion(record: record)
        }
    }
    
    // Fetches One User from CoreData by using their phone number //
    func fetchCoreDataUserWithNumber(number: String, completion: (user: User?) -> Void) {
        
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [number])
        request.predicate = predicate
        guard let fetchedUsers = (try? moc.executeFetchRequest(request) as? [User]),
            let users = fetchedUsers, user = users.first else {
                print("Couldn't fetch user")
                self.fetchCloudKitUserWithNumber(number, completion: { (contact) in
                    guard let contact = contact else {
                        completion(user: nil)
                        return
                    }
                    completion(user: contact)
                    return
                })
                return
        }
        completion(user: user)
        
    }
    // Fetches Contact with number
    func fetchCloudKitUserWithNumber(number: String, completion: (contact: User?) -> Void) {
        
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [number])
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            let contact = User(record: record)
            contact?.cloudKitRecord = record
            completion(contact: contact)
            self.saveContext()
        }) { (records, error) in
            if let _ = error {
                
            } else {
                print("Couldn't fetch CKRecord in fetchCloudKitUserWithNumber")
                completion(contact: nil)
            }
        }
    }
    
    // Fetches the loggedInUsers Contacts From Cloudkit if they get deleted. //
    func fetchCloudKitContacts(completion: (hasUsers: Bool)->Void) {
        guard let loggedInUser = loggedInUser else {
            print("No user logged in yet")
            return
        }
        
        guard let record = loggedInUser.cloudKitRecord,
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
    
    func checkForDuplicateContact(phoneNumber: String, completion: (hasContactAlready: Bool, isCKContact: Bool) -> Void) {
        
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [phoneNumber])
        request.predicate = predicate
        
        let users = (try? moc.executeFetchRequest(request)) as? [User]
        
        if let users = users {
            if users.count > 0 {
                checkIfContactIsInUsersCloudKitContacts(phoneNumber, completion: { (isCKContact) in
                    if isCKContact {
                        completion(hasContactAlready: true, isCKContact: isCKContact)
                    } else {
                        completion(hasContactAlready: true, isCKContact: isCKContact)
                    }
                    
                })
            } else {
                completion(hasContactAlready: false, isCKContact: false)
            }
        } else {
            completion(hasContactAlready: false, isCKContact: false)
        }
        
    }
    
    func checkIfContactIsInUsersCloudKitContacts(number: String, completion: (isCKContact: Bool) -> Void) {
        
        fetchCloudKitUserWithNumber(number) { (contact) in
            guard let contact = contact,
                contactReference = contact.cloudKitReference,
                loggedInUser = self.loggedInUser,
                loggedInUserRecord = loggedInUser.cloudKitRecord,
                loggedInUserReferences = loggedInUserRecord[User.contactsKey] as? [CKReference]   else {
                    completion(isCKContact: false)
                    return
            }
            
            for loggedInUserReference in loggedInUserReferences {
                if loggedInUserReference == contactReference {
                    self.deleteContactsFromCoreData([contact])
                    completion(isCKContact: true)
                    return
                }
            }
            self.deleteContactsFromCoreData([contact])
            completion(isCKContact: false)
        }
    }
    
    // Delete Contact
    
    func deleteContactFromCloudKit(contact: User) {
        guard let index = self.contacts.indexOf(contact) else {
            print("Couldn't find index for Contact")
            return
        }
        self.contacts.removeAtIndex(index)
        fetchUsersCloudKitRecord(contact) { (record) in
            guard let record = record else {
                print("Couldn't find Contact's record to delete his reference")
                return
            }
            let contactRecordName = record.recordID.recordName
            contact.cloudKitRecord = record
            
            // guard let reference = contact.cloudKitReference,
            guard let loggedInUser = self.loggedInUser else {
                print("no logged In user")
                return
            }
            
            if let record = loggedInUser.cloudKitRecord {
                guard var references = record[User.contactsKey] as? [CKReference] else {
                    print("No references in CloudKit")
                    return
                }
                
                loggedInUser.contactReferences = references
                let names = references.flatMap({$0.recordID.recordName})
                self.moc.deleteObject(contact)
                self.saveContext()
                guard let index = names.indexOf(contactRecordName) else {
                    print("No index")
                    return
                }
                
                references.removeAtIndex(index)
                
                record[User.contactsKey] = references
                loggedInUser.contactReferences = references
                CloudKitManager.cloudKitController.modifyRecords([record], perRecordCompletion: { (record, error) in
                    
                    }, completion: { (records, error) in
                        if let error = error {
                            print("Error Deleting Contact Reference. Error: \(error.localizedDescription)")
                        } else {
                            print("Successfully deleted contact reference")
                        }
                        self.deleteContactsFromCoreData([contact])
                        self.saveContext()
                })
                
            } else {
                
                self.fetchUsersCloudKitRecord(loggedInUser, completion: { (record) in
                    guard let record = record else {
                        return
                    }
                    guard var references = record[User.contactsKey] as? [CKReference] else {
                        print("No references in CloudKit")
                        return
                    }
                    loggedInUser.contactReferences = references
                    let recordNames = references.flatMap({$0.recordID.recordName})
                    
                    
                    guard let index = recordNames.indexOf(contactRecordName) else {
                        return
                    }
                    references.removeAtIndex(index)
                    
                    record[User.contactsKey] = references
                    CloudKitManager.cloudKitController.modifyRecords([record], perRecordCompletion: { (record, error) in
                        
                        }, completion: { (records, error) in
                            if let error = error {
                                print("Error Deleting Contact Reference. Error: \(error.localizedDescription)")
                            } else {
                                print("Successfully deleted contact reference")
                            }
                            self.saveContext()
                            self.deleteContactsFromCoreData([contact])
                            
                    })
                })
            }
        }
    }
    
    
    
    func updateContactsAppStatus(contact: User, completion: (wasSaved: Bool) -> Void) {
        contact.hasAppAccount = true
        fetchUsersCloudKitRecord(contact) { (record) in
            guard let record = record, loggedInUser = self.loggedInUser, loggedInUserRecord = loggedInUser.cloudKitRecord else {
                print("Couldn't fetch Contact's Record to add to User's Contacts in CK")
                return
            }
            
            contact.cloudKitRecord = record
            guard let contactReference = contact.cloudKitReference else {
                print("no contact reference available in updateContactsAppStatus ")
                return
            }
            
            // save contact to loggedInUser record's contacts property
            loggedInUser.contactReferences.append(contactReference)
            loggedInUserRecord[User.contactsKey] = loggedInUser.contactReferences
            CloudKitManager.cloudKitController.modifyRecords([loggedInUserRecord], perRecordCompletion: { (record, error) in
                
                
                }, completion: { (records, error) in
                    if let error = error {
                        print("Error saving Contact to User's Cloudkit contacts field. Error: \(error.localizedDescription)")
                        completion(wasSaved: false)
                    } else {
                        print("Saved Contact to Cloudkit")
                        completion(wasSaved: true)
                    }
                    
            })
        }
    }
    
    func deleteContactsFromCoreData(users: [User]) {
        
        for user in users {
            moc.deleteObject(user)
        }
        saveContext()
    }
    
    
    func saveNewContactToCloudKit(newContact: User, contactRecord: CKRecord, completion: (savedSuccessfully: Bool)-> Void) {
        newContact.hasAppAccount = true
        // Add contact to Logged In User's contact
        guard let loggedInUser = loggedInUser, loggedInUserRecord = loggedInUser.cloudKitRecord else { return }
        loggedInUser.contacts.append(newContact)
        UserController.sharedController.contacts.append(newContact)
        UserController.sharedController.saveContext()
        
        // If User has account add contact reference to User's CKrecord
        let contactReference = CKReference(recordID: contactRecord.recordID, action: .None)
        loggedInUser.contactReferences.append(contactReference)
        loggedInUserRecord[User.contactsKey] = loggedInUser.contactReferences
        
        // Add user to contact's contacts.
        newContact.contactReferences.append(loggedInUser.cloudKitReference!)
        contactRecord[User.contactsKey] = newContact.contactReferences
        
        // Modify both user's records.
        CloudKitManager.cloudKitController.modifyRecords([loggedInUserRecord], perRecordCompletion: { (record, error) in
            
            }, completion: { (records, error) in
                if let error = error {
                    print("Error modifying Contacts. Error: \(error.localizedDescription)")
                    UserController.sharedController.saveContext()
                    completion(savedSuccessfully: false)
                } else {
                    // If modifying records are successful present success alert to user.
                    newContact.hasAppAccount = true
                    UserController.sharedController.contacts = loggedInUser.contacts
                    UserController.sharedController.saveContext()
                    completion(savedSuccessfully: true)
                }
        })
        
        
    }
    
    // Saves the ManagedObject Context
    
    func saveContext() {
        do{
            try moc.save()
            print("Saved to context")
        }catch let error as NSError {
            print("Error saving to context. Error: \(error.localizedDescription)")
        }
        
        
    }
    
    
    
    
    
    
    
    
}