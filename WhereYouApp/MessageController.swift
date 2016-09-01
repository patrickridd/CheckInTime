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
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "hasResponded", cacheName: nil)
        
        _ = try? fetchedResultsController.performFetch()        
        
    }
    
    
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
        
        let message = Message(timeDue: timeDue, sender: sender, receiver: receiver)
      //  messages.insert(message, atIndex: 0)
        let record = CKRecord(recordType: Message.recordType)
        message.recordName = record.recordID.recordName
        message.record = record

        
        
        guard let senderRecord = sender.record,
            receiverRecord = receiver.record else {
                print("No sender/receiver record found")
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
                let _ = Message(record: record)
                
                
                
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
    
//    func subscribeToReceivedMessages() {
//        guard let userPhone = UserController.sharedController.loggedInUser?.phoneNumber else {
//            return
//        }
//    //    let userRecordID = CKRecordID(recordName: userPhone)
//        let predicate = NSPredicate(format: "receiverID == %@", argumentArray: [userPhone])
//        CloudKitManager.cloudKitController.subscribe(Message.recordType, predicate: predicate, subscriptionID: "receiver", contentAvailable: true, options: [.FiresOnRecordCreation,.FiresOnRecordUpdate]) { (subscription, error) in
//            
//            if let subscription = subscription {
//                print("Subscription Saved. Subscription: \(subscription.notificationInfo)")
//            } else {
//                print("Error saving subscription. Error: \(error?.localizedDescription)")
//            }
//        
//        }
//    }
    
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
                let _ = Message(record: record)
                saveContext()
                return
        }
        
        self.deleteMessage(fetchedMessage)
        let _ = Message(record: record)
        
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
