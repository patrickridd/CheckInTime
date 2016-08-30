//
//  MessageController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import CoreData

class MessageController {
    
    static let sharedController = MessageController()
    let moc = Stack.sharedStack.managedObjectContext
    
    var messages = [Message]()
    
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
        let message = Message(timeDue: timeDue, receiver: receiver, sender: sender)
        messages.insert(message, atIndex: 0)
        
        
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
