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
    
    
    
    
    /// Creates the Logged In User
    func createUser(name: String, phoneNumber: String, image: UIImage, completion: (success: Bool, user: User?) -> Void) {
        
        fetchAppleUser { (record) in
            guard let record = record,
                imageData = UIImagePNGRepresentation(image) else {
                    print("Cant get NSData from Image")
                    completion(success: false, user: nil)
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
            
            // Save user properties to cloudkit
            customUserRecord[User.nameKey] = user.name ?? user.phoneNumber
            customUserRecord[User.phoneNumberKey] = user.phoneNumber
            customUserRecord[User.imageKey] = user.imageAsset
            self.loggedInUser = user
            CloudKitManager.cloudKitController.saveRecord(customUserRecord, completion: { (record, error) in
                if let error = error {
                    print("Error saving to cloudkit. Error: \(error.localizedDescription)")
                    completion(success: false, user: user)
                } else {
                    user.hasAppAccount = 1
                    MessageController.sharedController.subscribeToMessages()
                    self.saveContext()
                    completion(success: true, user: user)
                }
            })
        }
    }
    
    
    /// Fetches the generic Users account Apple gives you in CloudKit.
    func fetchAppleUser(completion: (appleUserRecord: CKRecord?)->Void) {
        CloudKitManager.cloudKitController.fetchLoggedInUserRecord { (record, error) in
            guard let record = record else {
                completion(appleUserRecord: nil)
                print("Not signed in to cloudkit")
                return
            }
            completion(appleUserRecord: record)
        }
    }
    
    /// Checks for user who is logged in.
    func checkForCoreDataUserAccount(completion: (hasAccount: Bool, hasConnection: Bool)-> Void) {
        let sortDescriptor = NSSortDescriptor(key: "timeCreated", ascending: true)
        let request = NSFetchRequest(entityName: "User")
        request.sortDescriptors = [sortDescriptor]
        
        guard let fetchedUsers = (try? self.moc.executeFetchRequest(request) as? [User]),
            users = fetchedUsers where users.count > 0 else {
                completion(hasAccount: false, hasConnection: false)
                return
        }
        self.loggedInUser = users.first
        guard let loggedInUser = self.loggedInUser else {
            print("No user")
            completion(hasAccount: false, hasConnection: false)
            return
        }
        self.fetchContactsFromCoreData { (contacts) in
//            self.getNewPhotosFromContacts(contacts, completion: { 
//                
//                
//            })
            self.fetchUsersCloudKitRecord(loggedInUser, completion: { (record) in
                // Subscribe to Message Changes.
                guard let _ = record else {
                    completion(hasAccount: true, hasConnection: false)
                    return
                }
                CloudKitManager.cloudKitController.fetchSubscription("My Messages") { (subscription, error) in
                    guard let _ = subscription else {
                        print("Trying to subscribe to My Messages")
                        MessageController.sharedController.subscribeToMessages()
                        return
                    }
                    print("You are subscribed to received messages")
                }
           // MessageController.sharedController.fetchUnsyncedMessagesFromCloudKitToCoreData(loggedInUser)
                completion(hasAccount: true, hasConnection: true)
            })
        }
    }
    
    /// To sync the simulator with a picture
    func getNewPhotosFromContacts(contacts: [User], completion: ()-> Void) {
        for contact in contacts {
            self.fetchUsersCloudKitRecord(contact, completion: { (record) in
                guard let record = record else {
                    return
                }
                let updateContact = User(record: record)
                updateContact?.name = contact.name
                self.deleteContactsFromCoreData([contact])
                completion()
            })
            
        }
    }
    
    
    /// Fetches all users in core data except the Logged In User
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
    
    /// Check by user phone number if contacts who didn't have account now do have an account with the app.
    func checkIfContactsHaveSignedUpForApp(completion: (newAppAcctUsers: Bool, updatedUsers: [User]?)->Void) {
        fetchContactsWhoDontHaveApp { (users) in
            guard let users = users else {
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
    }
    
    /// Helper Method that fetches Contacts who are not signed up for the App
    func fetchContactsWhoDontHaveApp(completion: (users: [User]? )-> Void) {
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "hasAppAccount == 0")
        request.predicate = predicate
        guard let users = (try? moc.executeFetchRequest(request) as! [User]) else {
            completion(users: nil)
            return
        }
        if users.count < 1 {
            print("No users to Check for App status")
            completion(users: nil)
            return
        }
    }
    
    /// Checks if current user's contacts have deleted their account by checking for their records in CloudKit.
    func checkIfContactsHaveDeletedApp(completion: (haveDeletedApp: Bool, updatedUsers: [User]?) -> Void) {
        fetchContactsWhoHaveApp { (users) in
            guard let users = users else {
                completion(haveDeletedApp: false, updatedUsers: nil)
                return
            }
            var deletedUsers = [User]()
            for user in users {
                self.checkIfContactHasAccount(user.phoneNumber, completion: { (record) in
                    if record == nil {
                        deletedUsers.append(user)
                    }
                    if deletedUsers.count < 1 {
                        completion(haveDeletedApp: false, updatedUsers: nil)
                    } else {
                        for deletedUser in deletedUsers {
                            self.updateContactsAppStatus(deletedUser, completion: { (wasSaved) in
                                
                            })
                        }
                        completion(haveDeletedApp: true, updatedUsers: deletedUsers)
                    }
                })
            }
        }
    }
    
    
    /// Helper methods that fetches all Contacts who have downloaded the App.
    func fetchContactsWhoHaveApp(completion: (users: [User]?)->Void) {
        guard let loggedInUser = loggedInUser else {
            return
        }
        // Fetch all users who have app AND isn't the logged in user.
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "hasAppAccount == 1")
        let predicateUser = NSPredicate(format: "phoneNumber != %@", argumentArray: [loggedInUser.phoneNumber])
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, predicateUser])
        request.predicate = compoundPredicate
        
        guard let users = (try? moc.executeFetchRequest(request) as! [User]) else {
            completion(users: nil)
            return
        }
        // If no users have app in contacts return false to users having deleted app.
        if users.count < 1 {
            print("No users to Check for App status")
            completion(users: nil)
            return
        }
    }
    
    /// Fetches Any User with their phone number from CloudKit
    func fetchUsersCloudKitRecord(user: User, completion: (record: CKRecord?) ->Void) {
        
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [user.phoneNumber])
        
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            
        }) { (records, error) in
            guard let records = records,
                record = records.first else {
                    print("No record found for user in cloudkit. Error: \(error?.localizedDescription)")
                    completion(record: nil)
                    return
            }
            user.cloudKitRecord = record
            completion(record: record)
        }
    }
    
    /// Fetches One User from CoreData by using their phone number
    func fetchUsersForMessage(number: String, completion: (user: User?) -> Void) {
        
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [number])
        request.predicate = predicate
        
        guard let fetchedUsers = (try? moc.executeFetchRequest(request) as? [User]),
            let users = fetchedUsers, user = users.first  else {
                print("Couldn't fetch user")
                self.fetchCloudKitUserWithNumber(number, completion: { (contact) in
                    
                    guard let contact = contact else {
                        guard let image = UIImage(named: "profile"), let imageData = UIImagePNGRepresentation(image) else {
                            return
                        }
                        let user = User(name: number, phoneNumber: number, imageData: imageData, hasAppAccount: true)
                        completion(user: user)
                        return
                    }
                    contact.name = number
                    completion(user: contact)
                    return
                })
                return
        }
        saveContext()
        completion(user: user)
    }
    
    /// Fetches Contact in CloudKit with phone number.
    func fetchCloudKitUserWithNumber(number: String, completion: (contact: User?) -> Void) {
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [number])
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            
            let contact = User(record: record)
            contact?.cloudKitRecord = record
            completion(contact: contact)
            self.saveContext()
        }) { (records, error) in
            if records?.count < 1 {
                completion(contact: nil)
            }
        }
    }
    
    /// Fetches the loggedInUsers Contacts From Cloudkit if they get deleted.
    func fetchCloudKitContacts(completion: (hasUsers: Bool)->Void) {
        guard let loggedInUser = loggedInUser, record = loggedInUser.cloudKitRecord,
            references = record[User.contactsKey] as? [CKReference] else {
                completion(hasUsers: false)
                return
        }
        loggedInUser.contactReferences = references
        let predicate = NSPredicate(format: "recordID IN %@", argumentArray: [references])
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            
        }) { (records, error) in
            guard let records = records else {
                completion(hasUsers: false)
                return
            }
            if records.count < 1 {
                completion(hasUsers: false)
                return
            }
            let _ = records.flatMap({User(record: $0)})
            self.saveContext()
            completion(hasUsers: true)
        }
    }
    
    /// Checks if Contact has downloaded this app so User know if they can communicate with each other.
    func checkIfContactHasAccount(newContactPhone: String, completion: (record: CKRecord?) -> Void) {
        
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [newContactPhone])
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
    
    /// Checks For Duplicate Contact in CoreData
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
                        self.deleteContactsFromCoreData(users)
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
    
    /// Checks If Contact is User's contacts property so the contact isn't added twice.
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
                if loggedInUserReference.recordID.recordName == contactReference.recordID.recordName {
                    self.deleteContactsFromCoreData([contact])
                    self.saveContext()
                    completion(isCKContact: true)
                    return
                }
            }
            if loggedInUserReferences.count < 1 {
                self.deleteContactsFromCoreData([contact])
                completion(isCKContact: false)
            }
        }
    }
    
    
    /// Deletes User's Contact From CloudKit contacts property.
    func deleteContactFromCloudKit(contact: User) {
        fetchUsersCloudKitRecord(contact) { (record) in
            guard let record = record else {
                print("Couldn't find Contact's record to delete his reference")
                return
            }
            let contactRecordName = record.recordID.recordName
            contact.cloudKitRecord = record
            guard let loggedInUser = self.loggedInUser, let userRecord = loggedInUser.cloudKitRecord, var references = userRecord[User.contactsKey] as? [CKReference]   else {
                print("no logged In user")
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
                userRecord[User.contactsKey] = references
                loggedInUser.contactReferences = references
                CloudKitManager.cloudKitController.modifyRecords([record], perRecordCompletion: { (record, error) in
                    }, completion: { (records, error) in
                        if let error = error {
                            print("Error Deleting Contact Reference. Error: \(error.localizedDescription)")
                        } else {
                            print("Successfully deleted contact reference")
                        }
                        self.saveContext()
                })
        }
    }
    
    
    /// Deletes the Current User Account from CloudKit, CoreData, and Cancels all notifications.
    func deleteAccount(completion: ()->Void) {
        guard let loggedInUser = loggedInUser,
            loggedInUserRecord = loggedInUser.cloudKitRecord else {
                completion()
                return
        }
        self.deleteAccountFromCoreData()
        // Deletes Logged In User's CKRecord
        CloudKitManager.cloudKitController.deleteRecordWithID(loggedInUserRecord.recordID) { (recordID, error) in
            if let error = error {
                print("Error Deleting User Record. Error: \(error.localizedDescription)")
                completion()
            } else {
                print("Successfully Deleted User Profile")
                completion()
            }
        }
    }
    
    
    /// Deletes the User's Contacts and Messages from CoreData.
    func deleteAccountFromCoreData() {
        let messageRequest = NSFetchRequest(entityName: "Message")
        guard let fetchMessages = try? moc.executeFetchRequest(messageRequest) as? [Message],
            let messages = fetchMessages else {
                return
        }
        // Deletes messages already loaded into MOC
        MessageController.sharedController.deleteMessagesFromCoreData(messages)
        
        // Deletes Message entity
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: messageRequest)
        do {
            try moc.executeRequest(deleteRequest)
        } catch let error as NSError {
            debugPrint(error)
        }
        // Deletes Users
        let usersRequest = NSFetchRequest(entityName: "User")
        
        let usersDeleteRequest = NSBatchDeleteRequest(fetchRequest: usersRequest)
        do {
            try moc.executeRequest(usersDeleteRequest)
        } catch let error as NSError {
            debugPrint(error)
        }
        moc.reset()
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    
    
    /* Updates Local Contact's hasAppAccount Bool. If Contact has App, Contact is saved into User's CK contacts property.
     // If Contact doesn't have app. If will fail and return
     */
    func updateContactsAppStatus(contact: User, completion: (wasSaved: Bool) -> Void) {
        if contact.hasAppAccount == 1 {
            contact.hasAppAccount = 0
        } else {
            contact.hasAppAccount = 1
        }
        saveContext()
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
    
    
    
    /// Deletes contacs from CoreData.
    func deleteContactsFromCoreData(users: [User]) {
        for user in users {
            moc.deleteObject(user)
            saveContext()
        }
        
    }
    
    /// Saves a new Contact to the Users Contact's Property in Cloudkit.
    func saveNewContactToCloudKit(newContact: User, contactRecord: CKRecord, completion: (savedSuccessfully: Bool)-> Void) {
        newContact.hasAppAccount = true
        // Add contact to Logged In User's contact
        guard let loggedInUser = loggedInUser, loggedInUserRecord = loggedInUser.cloudKitRecord else { return }
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
                    UserController.sharedController.saveContext()
                    completion(savedSuccessfully: true)
                }
        })
    }
    
    /// Saves the ManagedObject Context
    func saveContext() {
        do{
            try moc.save()
            print("Saved to context")
        }catch let error as NSError {
            print("Error saving to context. Error: \(error.localizedDescription)")
        }
    }
    
}
