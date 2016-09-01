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
       // self.messages = (fetchedResultsController.fetchedObjects as? [Message]) ?? []
        
    }
    
    
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
        
        let message = Message(timeDue: timeDue, sender: sender, receiver: receiver)
      //  messages.insert(message, atIndex: 0)
         saveContext()
        guard let senderRecord = message.sender.record,
            receiverRecord = message.receiver.record else {
                return
        }
        let senderReference = CKReference(record: senderRecord, action: .None)
        let receiverReference = CKReference(record: receiverRecord, action: .None)
        
        // Save message to CloudKit
        let record = CKRecord(recordType: Message.recordType)
        message.record = record
        record[Message.senderIDKey] = sender.phoneNumber
        record[Message.receiverIDKey] = receiver.phoneNumber
        record[Message.hasRespondedKey] = message.hasResponded
        record[Message.users] = [senderReference, receiverReference]
       // record[Message.latitudeKey] = message.latitude
       // record[Message.longitudeKey] = message.longitude
       // record[Message.textKey] = message.text
        record[Message.timeDueKey] = message.timeDue
        record[Message.timeSentKey] = message.timeSent
       // record[Message.timeRespondedKey] = message.timeResponded
        
        CloudKitManager.cloudKitController.saveRecord(record) { (record, error) in
        self.addSubscriptionToMessage(message, alertBody: "New WhereYouApp Update")
       //     self.messages.append(message)
            print("Saved message to cloudkit")
        }
    }
    
    
    func addSubscriptionToMessage(message: Message, alertBody: String?) {
        
        guard let record = message.record, senderRecord = message.sender.record,
           receiverRecord = message.receiver.record else { return }
        
        let senderReference = CKReference(record: senderRecord, action: .None)
        let receiverReference = CKReference(record: receiverRecord, action: .None)
        
        let subscriptionID = record.recordID.recordName
        let predicate = NSPredicate(format: "users CONTAINS %@", argumentArray: [receiverReference,senderReference])
        
        CloudKitManager.cloudKitController.subscribe(Message.recordType, predicate: predicate, subscriptionID: subscriptionID, contentAvailable: true, alertBody: alertBody, desiredKeys: nil, options: .FiresOnRecordCreation) { (subscription, error) in
            
            if error == nil {
                print("Successful Subscription")
            } else {
                print("Error adding Subscription. Error: \(error?.localizedDescription)")
            }
            
        }
    }
    
    func updateOrAddRemoteNotification(record: CKRecord) {
        
        let ckRecordID = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
        let request = NSFetchRequest(entityName: Message.recordType)
        let predicate = NSPredicate(format: "ckRecordID == ", argumentArray: [ckRecordID])
        request.predicate = predicate
        
        guard let fetchedMessages = try? moc.executeFetchRequest(request) as? [Message],
            messages = fetchedMessages,
               fetchedMessage = messages.first else {
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
