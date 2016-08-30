//
//  MessageController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation

class MessageController {
    
    static let sharedController = MessageController()
    let moc = Stack.sharedStack.managedObjectContext
    
    var messages = [Message]()
    
    
    init() {
        
        
        
        
        
    }
    
    func createMessage(sender: User, receiver: User, timeDue: NSDate) {
        let message = Message(timeDue: timeDue, receiver: receiver, sender: sender)
        messages.insert(message, atIndex: 0)
        
        
    }
    
    func deleteMessage(message: Message) {
        
    }
    
    func saveContext() {
        do {
            try moc.save()
        } catch let error as NSError{
            print("Couldn't save to context: Error: \(error.localizedDescription)")
        }
        
    }
    
    
    
}
