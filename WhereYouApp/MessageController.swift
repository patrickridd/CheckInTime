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
        fetchUnsyncedMessagesFromCloudKitToCoreData()
        
    }
    
    /* Creates a new message  with between two users and saves it both in cloudkit and core data.
     */
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
        sender.hasAppAccount = true
        sender.hasAppAccount = true
        
        // create new Message
        let message = Message(timeDue: timeDue, sender: sender, receiver: receiver)
        
        // Create CKRecord and give your model the record and recordName
        // recordName can then be fetched from core data
        let record = CKRecord(recordType: Message.recordType)
        message.recordName = record.recordID.recordName
        message.record = record
        message.ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
        
        
        
        // Get CKRecord Data
        guard let senderData = sender.ckRecordID,
            receiverData = receiver.ckRecordID else {
                print("CKRecord NSData was nil")
                return
        }
        
        // Convert Data back to CKRecord so you can create users reference
        guard let senderRecord = NSKeyedUnarchiver.unarchiveObjectWithData(senderData) as? CKRecord,
            receiverRecord = NSKeyedUnarchiver.unarchiveObjectWithData(receiverData) as? CKRecord else {
                print("Couldn't get back CKRecords from NSData")
                return
        }
        
        // Save message to CloudKit
        
        record[Message.senderIDKey] = sender.phoneNumber
        record[Message.receiverIDKey] = receiver.phoneNumber
        record[Message.hasRespondedKey] = message.hasResponded
        let senderReference = CKReference(recordID: senderRecord.recordID, action: .None)
        let receiverReference = CKReference(recordID: receiverRecord.recordID, action: .None)
        record[Message.users] = [senderReference, receiverReference]
        
        
        // record[Message.latitudeKey] = message.latitude
        // record[Message.longitudeKey] = message.longitude
        // record[Message.textKey] = message.text
        record[Message.timeDueKey] = message.timeDue
        record[Message.timeSentKey] = message.timeSent
        // record[Message.timeRespondedKey] = message.timeResponded
        
        CloudKitManager.cloudKitController.saveRecord(record) { (record, error) in
            // self.addSubscriptionToMessage(message, alertBody: "New WhereYouApp Update")
            //     self.messages.append(message)
            print("Saved message to cloudkit")
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
    
    func fetchUnsyncedMessagesFromCloudKitToCoreData() {
        
        let request = NSFetchRequest(entityName: "Message")
        
        // Get messages in CoreData
        guard let coreDataMessages = (try? moc.executeFetchRequest(request) as! [Message]) else {
            return
        }
        
        // Get the Message References for predicate for CloudKit
        let messageReferences = coreDataMessages.flatMap({$0.cloudKitReference})
        // The predicate will fetch for any Message that doesn't have a recordID associated with a message CoreData already has
        let predicate = NSPredicate(format: "NOT(recordID IN %@)", argumentArray: [messageReferences])
        
        CloudKitManager.cloudKitController.fetchRecordsWithType(Message.recordType, predicate: predicate, recordFetchedBlock: { (record) in
            
            
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
                print("\(message.sender.name)")

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
