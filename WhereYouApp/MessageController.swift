//
//  MessageController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import CoreData
import CloudKit
import UIKit

class MessageController {
    
    static let sharedController = MessageController()
    let moc = Stack.sharedStack.managedObjectContext
    let fetchedResultsController: NSFetchedResultsController
    
    
    
    init() {
        
        let request = NSFetchRequest(entityName: "Message")
        let sortDescriptor = NSSortDescriptor(key: "timeSent", ascending: false)
        let sortDescriptorBool = NSSortDescriptor(key: "hasResponded", ascending: false)
        
        request.sortDescriptors = [sortDescriptor, sortDescriptorBool]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "hasResponded", cacheName: nil)
        
        _ = try? fetchedResultsController.performFetch()
      
        
    }
    
    /* Creates a new message  with between two users and saves it both in cloudkit and core data.
     */
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
       
        
        // create new Message
        let message = Message(timeDue: timeDue, sender: sender, receiver: receiver)
        
        // Create CKRecord and give your model the record and recordName
        // recordName can then be fetched from core data
        let messageRecord = CKRecord(recordType: Message.recordType)
        message.recordName = messageRecord.recordID.recordName
        message.record = messageRecord
        message.ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(messageRecord.recordID)
        
        
        // Get records From Sender and Receiver
        
        UserController.sharedController.fetchUsersCloudKitRecord(sender) { (record) in
            guard let record = record else {
                print("No sender record found")
                return
            }
            sender.cloudKitRecord = record
            UserController.sharedController.fetchUsersCloudKitRecord(receiver, completion: { (record) in
                guard let record = record else {
                    print("No Receiver record found")
                    return
                }
                receiver.cloudKitRecord = record
            
                guard let senderRecord = sender.cloudKitRecord,
                    receiverRecord = receiver.cloudKitRecord else {
                        print("Couldn't get back CKRecords from NSData")
                        return
                }
                // Save message to CloudKit
                
                messageRecord[Message.senderIDKey] = sender.phoneNumber
                messageRecord[Message.receiverIDKey] = receiver.phoneNumber
                messageRecord[Message.hasRespondedKey] = message.hasResponded
                let senderReference = CKReference(recordID: senderRecord.recordID, action: .None)
                let receiverReference = CKReference(recordID: receiverRecord.recordID, action: .None)
                messageRecord[Message.users] = [senderReference, receiverReference]
            
                messageRecord[Message.timeDueKey] = message.timeDue
                messageRecord[Message.timeSentKey] = message.timeSent
                
                CloudKitManager.cloudKitController.saveRecord(messageRecord) { (record, error) in
                    print("Saved message to cloudkit")
                    self.saveContext()
                }
            })
            
        }
        
    }
    
    /* Fetches all messages in cloudkit that the loggedInUser is associated with
     */
    
    func fetchAllMessagesFromCloudKit(completion: ()-> Void) {
        
        CloudKitManager.cloudKitController.checkForCloudKitUserAccount { (hasCloudKitAccount, userRecord) in
            guard let userRecord = userRecord else {
                return
            }
            
            let reference = CKReference(recordID: userRecord.recordID, action: .None)
            
            let predicate = NSPredicate(format: "users CONTAINS %@", argumentArray: [reference])
            
            CloudKitManager.cloudKitController.fetchRecordsWithType(Message.recordType, predicate: predicate, recordFetchedBlock: { (record) in
                let message = Message(record: record)
                print("\(message?.sender.name)")
                
            }) { (records, error) in
                if let error = error {
                    print("No messages. Error: \(error.localizedDescription)")
                    completion()
                    return
                }
                self.saveContext()
                completion()
            }
        }
    }
    
    
    /*
     Fetches Messages from cloudkit that havent been saved to core data yet.
     */
    
    func fetchUnsyncedMessagesFromCloudKitToCoreData(user: User) {
        
        
        let request = NSFetchRequest(entityName: "Message")
        guard let reference = user.cloudKitReference else {
            print("No user reference to fetch unsynced records")
            return
        }
        // Get messages in CoreData
        guard let coreDataMessages = (try? moc.executeFetchRequest(request) as! [Message]) else {
            return
        }
        
        // Get the Message References for predicate for CloudKit
        let messageReferences = coreDataMessages.flatMap({$0.cloudKitReference})
        let messagePredicate = NSPredicate(format: "NOT(recordID IN %@)", argumentArray: [messageReferences])
        // The predicate will fetch for any Message that doesn't have a recordID associated with a message CoreData already has
        let usersPredicate = NSPredicate(format: "users CONTAINS %@", argumentArray: [reference])
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [messagePredicate,usersPredicate])
        
        CloudKitManager.cloudKitController.fetchRecordsWithType(Message.recordType, predicate: compoundPredicate, recordFetchedBlock: { (record) in
            
        }) { (records, error) in
            guard let records = records else {
                print("Message Records were nil")
                return
            }
            // Initializes new Messages found from CloudKit and saves them to CoreData
            let messages = records.flatMap({Message(record: $0)})
            if messages != [] {
                print("Fetched new Message Records from cloudkit")
            } else {
                print("No new messages from cloudkit found")
            }
            self.saveContext()
        }
    }
    
    
    /* Subscribes the logged in user to all messages in cloudkit that contain its Users record in the Message record's
     "users" property.
     */
    func subscribeToMessages() {
        guard let userRecord = UserController.sharedController.loggedInUser?.cloudKitRecord else {
            print("No ckrecord to subscribe")
            return
        }
        let reference = CKReference(recordID: userRecord.recordID, action: .None)
        
        let predicate = NSPredicate(format: "users CONTAINS %@", argumentArray: [reference])
        CloudKitManager.cloudKitController.subscribe(Message.recordType, predicate: predicate, subscriptionID: "My Messages", contentAvailable: true, options: [.FiresOnRecordCreation,.FiresOnRecordUpdate]) { (subscription, error) in
            
            if let subscription = subscription {
                print("Subscription Saved. Subscription: \(subscription.notificationInfo)")
            } else {
                print("Error saving subscription. Error: \(error?.localizedDescription)")
            }
        }
    }
    
    
    
    
    func createUserContactFromNewMessage(messageSender: User) {
        
        let predicate = NSPredicate(format: "phoneNumber == %@", argumentArray: [messageSender.phoneNumber])
        
        CloudKitManager.cloudKitController.fetchRecordsWithType(User.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            let user = User(record: record)
            self.saveContext()
            
            }) { (records, error) in
                if let error = error {
                    print("Error finding sender of message to add to contacts. Error: \(error.localizedDescription)")
                } else {
                    print("Saved to contact to core data")
                }
                
        
        }
        
        
    }
    
    
    /* This method takes a record obtained from a remote notification and discerns if it is a new message or an updated one.
     If it is a new message it will simply create a new one and save it to the context. If it is an updated message then it deletes the original message from core data and creates the new updated one and saves it to core data.
     */
    func updateOrAddRemoteNotification(record: CKRecord) {
        
        let request = NSFetchRequest(entityName: Message.recordType)
        let predicate = NSPredicate(format: "recordName == %@", argumentArray: [record.recordID.recordName])
        request.predicate = predicate
        
        guard let fetchedMessages = try? moc.executeFetchRequest(request) as? [Message],
            messages = fetchedMessages where messages.count > 0,
            let fetchedMessage = messages.first else {
                
                let message = Message(record: record)!
                
                scheduleLocalNotification(message)
                
                saveContext()
                return
        }
        self.deleteMessage(fetchedMessage)
        let message = Message(record: record)
        
        print("\(message?.sender.name)")
        saveContext()
    }
    
    func scheduleLocalNotification(message: Message) {
        
        
        let localNotification = UILocalNotification()
        localNotification.alertTitle = "WhereYouApp"
        localNotification.alertBody =   "\(message.sender.name) wants you to check in now"
        localNotification.fireDate = message.timeDue
        
        localNotification.repeatInterval = NSCalendarUnit.Day
        localNotification.category = "CheckInTime"
        UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
    }

    
    
    
    
    func deleteMessage(message: Message) {
        moc.deleteObject(message)
        guard let messageRecord = message.cloudKitRecord else {
            print("Couldn't get messages record to delete it.")
            saveContext()
            return
        }
        CloudKitManager.cloudKitController.deleteRecordWithID(messageRecord.recordID) { (recordID, error) in
            if let error = error {
                print("Error Deleting Message. Error: \(error.localizedDescription)")
            } else {
                print("Successfully Deleted Message Record.")
            }
        }
        
        saveContext()
    }
    
    func saveContext() {
        do {
            try moc.save()
            print("Saved to context")
        } catch let error as NSError{
            print("Couldn't save to context: Error: \(error.localizedDescription)")
        }
        
    }

}
