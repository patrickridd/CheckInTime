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


class MessageController {
    
    static let sharedController = MessageController()
    let moc = Stack.sharedStack.managedObjectContext

    
    let fetchedResultsController: NSFetchedResultsController
    
    init() {
        
        let request = NSFetchRequest(entityName: "Message")
        let sortDescriptor = NSSortDescriptor(key: "timeSent", ascending: false)
        let sortDescriptorBool = NSSortDescriptor(key: "hasResponded", ascending: false)
        
        request.sortDescriptors = [sortDescriptor, sortDescriptorBool]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "senderID", cacheName: nil)
        
        _ = try? fetchedResultsController.performFetch()        
        
    }
    
    
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
        
        // create new Message
        let message = Message(timeDue: timeDue, sender: sender, receiver: receiver)

        // Create CKRecord and give your model the record and recordName
        // recordName can then be fetched from core data
        let record = CKRecord(recordType: Message.recordType)
        message.recordName = record.recordID.recordName
        message.record = record

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
    
    
    
    
    func fetchMessagesFromCloudKit(completion: ()-> Void) {
        
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
    

    
    
    func subscribeToMessages() {
        guard let userRecord = UserController.sharedController.loggedInUser?.record else {
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
    

    
    func updateOrAddRemoteNotification(record: CKRecord) {
        
        
        let request = NSFetchRequest(entityName: Message.recordType)
        let predicate = NSPredicate(format: "recordName == %@", argumentArray: [record.recordID.recordName])
        request.predicate = predicate
        
        guard let fetchedMessages = try? moc.executeFetchRequest(request) as? [Message],
            messages = fetchedMessages where messages.count > 0,
               let fetchedMessage = messages.first else {
                let message = Message(record: record)!
                print("\(message.sender.name)")
                
                saveContext()
                return
        }
        
        self.deleteMessage(fetchedMessage)
        let message = Message(record: record)
        print("\(message?.sender.name)")
        saveContext()
        
        
        
    }

    
    func deleteMessage(message: Message) {
        moc.deleteObject(message)
        saveContext()
    }
    
    func saveContext() {
        do {
            try moc.save()
        } catch let error as NSError{
            print("Couldn't save to context: Error: \(error.localizedDescription)")
        }
        
    }
    
    
    
}
