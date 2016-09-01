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

let MessagesDidRefreshNotification = "MessagesDidRefreshNotification"

class MessageController {
    
    static let sharedController = MessageController()
    let moc = Stack.sharedStack.managedObjectContext
//    
//    var messages = [Message]() {
//        didSet{
//            let nc = NSNotificationCenter.defaultCenter()
//            nc.postNotificationName(MessagesDidRefreshNotification, object: nil)
//        }
//    }
    
    let fetchedResultsController: NSFetchedResultsController
    
    init() {
        
        let request = NSFetchRequest(entityName: "Message")
        let sortDescriptor = NSSortDescriptor(key: "timeSent", ascending: false)
        
        request.sortDescriptors = [sortDescriptor]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "timeSent", cacheName: nil)
        
        _ = try? fetchedResultsController.performFetch()

        // Subscribe to Message Changes.
        CloudKitManager.cloudKitController.fetchSubscription("receiver") { (subscription, error) in
            guard let subscription = subscription else {
                print("Trying to subscribe to received messages")
                self.subscribeToReceivedMessages()
                return
            }
            print("You are subscribed to received messages. Subscription: \(subscription.subscriptionID)")
        }
        
        
        
    }
    
    
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
        
        let message = Message(timeDue: timeDue, sender: sender, receiver: receiver)
      //  messages.insert(message, atIndex: 0)
         saveContext()
       
        
        // Save message to CloudKit
        let record = CKRecord(recordType: Message.recordType)
        message.record = record
        record[Message.senderIDKey] = sender.phoneNumber
        record[Message.receiverIDKey] = receiver.phoneNumber
        record[Message.hasRespondedKey] = message.hasResponded
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
    
    
//    func addSubscriptionToMessage(message: Message, alertBody: String?) {
//        guard let record = message.record else {
//            return
//        }
//        
//        let reference = CKReference(recordID: record.recordID, action: .DeleteSelf)
//        
//        let subscriptionID = record.recordID.recordName
//        let predicate = NSPredicate(format: "recordID == %@", argumentArray: [reference])
//        
//        CloudKitManager.cloudKitController.subscribe(Message.recordType, predicate: predicate, subscriptionID: subscriptionID, contentAvailable: true, alertBody: alertBody, desiredKeys: nil, options: .FiresOnRecordCreation) { (subscription, error) in
//            
//            if error == nil {
//                print("Successful Subscription")
//            } else {
//                print("Error adding Subscription. Error: \(error?.localizedDescription)")
//            }
//            
//        }
//    }
    
    func subscribeToReceivedMessages() {
        guard let userPhone = UserController.sharedController.loggedInUser?.phoneNumber else {
            return
        }
    //    let userRecordID = CKRecordID(recordName: userPhone)
        let predicate = NSPredicate(format: "receiverID == %@", argumentArray: [userPhone])
        CloudKitManager.cloudKitController.subscribe(Message.recordType, predicate: predicate, subscriptionID: "receiver", contentAvailable: true, options: [.FiresOnRecordCreation,.FiresOnRecordUpdate]) { (subscription, error) in
            
            if let subscription = subscription {
                print("Subscription Saved. Subscription: \(subscription.notificationInfo)")
            } else {
                print("Error saving subscription. Error: \(error?.localizedDescription)")
            }
        
        }
        
        
        
        
        
    }
    
    func updateOrAddRemoteNotification(record: CKRecord) {
        
        let ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
        let request = NSFetchRequest(entityName: Message.recordType)
        let predicate = NSPredicate(format: "ckRecordID CONTAINS %@", argumentArray: [ckRecordID])
        request.predicate = predicate
        
        guard let fetchedMessages = try? moc.executeFetchRequest(request) as? [Message],
            messages = fetchedMessages where messages.count > 0,
               let fetchedMessage = messages.first else {
                let messages = Message(record: record)
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
