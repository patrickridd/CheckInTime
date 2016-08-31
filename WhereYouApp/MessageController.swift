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
    
    var messages = [Message]() {
        didSet{
           // let nc = NSNotification
        }
    }
    
    let fetchedResultsController: NSFetchedResultsController
    
    init() {
        
        let request = NSFetchRequest(entityName: "Message")
        let sortDescriptor = NSSortDescriptor(key: "timeSent", ascending: false)
        
        request.sortDescriptors = [sortDescriptor]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "timeSent", cacheName: nil)
        
        _ = try? fetchedResultsController.performFetch()
        self.messages = (fetchedResultsController.fetchedObjects as? [Message]) ?? []
        
    }
    
    
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
        
        let message = Message(timeDue: timeDue, sender: sender, receiver: receiver)
        messages.insert(message, atIndex: 0)
        
        
        saveContext()
        
        // Save message to CloudKit
        let record = CKRecord(recordType: "Message")
        record[Message.senderIDKey] = sender.phoneNumber
        record[Message.receiverIDKey] = receiver.phoneNumber
        record[Message.hasRespondedKey] = message.hasResponded
        record[Message.latitudeKey] = message.latitude
        record[Message.longitudeKey] = message.longitude
        record[Message.textKey] = message.text
        record[Message.timeDueKey] = message.timeDue
        record[Message.timeSentKey] = message.timeSent
        record[Message.timeRespondedKey] = message.timeResponded
        CloudKitManager.cloudKitController.saveRecord(record) { (record, error) in
            
            print("Saved message to cloudkit")
        }
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
