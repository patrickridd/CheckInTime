//
//  ContactDetailViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CoreData
import MessageUI
import CloudKit

class ContactDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, UIGestureRecognizerDelegate {
    
    
    var contact: User?
    var fetchedResultsController: NSFetchedResultsController!
    let moc = Stack.sharedStack.managedObjectContext
    
    
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    @IBOutlet weak var contactImage: UIImageView!
    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet var dueDatePicker: UIDatePicker!
    @IBOutlet weak var tableView: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let contact = contact else {
            return
        }
        if contact.hasAppAccount == false {
            self.presentNoUserAccount(contact)
        }
        
        
        setupFetchController(contact)
        fetchedResultsController.delegate = self
        dateTextField.inputView = dueDatePicker
        updateWith(contact)
        
    }
    
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // self.navigationController?.tabBarController?.
    }
    
    func updateWith(contact: User) {
        
        let formattedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(contact.phoneNumber)
        
        self.contactImage.image = contact.photo
        self.nameLabel.text = contact.name ?? formattedPhoneNumber
        self.numberLabel.text = formattedPhoneNumber
        
    }
    
    func presentNoUserAccount(newContact: User) {
        let noUserAccountAlert = UIAlertController(title: "\(newContact.name ?? newContact.phoneNumber) doesn't have WhereYouApp", message: "Would you like to suggest that they download WhereYouApp", preferredStyle: .Alert)
        
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil)
        let recommendAction = UIAlertAction(title: "Recommend", style: .Default) { (_) in
            
            let messageVC = MFMessageComposeViewController()
            if MFMessageComposeViewController.canSendText() == true {
                messageVC.body = "I'd like you to download WhereYouApp so I can know WhereYouApp"
                messageVC.recipients = [newContact.phoneNumber]
                //  messageVC.messageComposeDelegate = self
                messageVC.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
                messageVC.navigationBar.translucent = false
                self.presentViewController(messageVC, animated: true, completion: {
                    noUserAccountAlert.view.tintColor = UIColor ( red: 0.5004, green: 1.0, blue: 0.556, alpha: 1.0 )
                })
            } else {
                
            }
        }
        noUserAccountAlert.addAction(dismissAction)
        noUserAccountAlert.addAction(recommendAction)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(noUserAccountAlert, animated: true, completion: nil)
            
        })
        
    }

    
    
    func setupFetchController(contact: User) {
        
        let request = NSFetchRequest(entityName: "Message")
        let descriptor = NSSortDescriptor(key: "timeSent", ascending: false)
        request.sortDescriptors = [descriptor]
        let receiverPredicate = NSPredicate(format: "receiver == %@", argumentArray: [contact])
        let senderPredicate = NSPredicate(format: "sender == %@", argumentArray: [contact])
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [receiverPredicate,senderPredicate])
        request.predicate = compoundPredicate
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "hasResponded" , cacheName: nil  )
        
        let _ = try? fetchedResultsController.performFetch()
        
        
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        dateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)
        dateTextField.resignFirstResponder()
        if gestureRecognizer is UITapGestureRecognizer {
            let location = touch.locationInView(tableView)
            return (tableView.indexPathForRowAtPoint(location) == nil)
        }
        return true
    }
    
    @IBAction func whereYouAppButtonTapped(sender: AnyObject) {
        guard let sender = UserController.sharedController.loggedInUser,
            receiver = contact else {
                print("No logged in user or contact")
                return
        }
        if receiver.hasAppAccount == 0 {
            self.presentNoUserAccount(receiver)
            return
        }
        dateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)
        
            dispatch_async(dispatch_get_main_queue(), {
            MessageController.sharedController.createMessage(sender, receiver: receiver, timeDue: self.dueDatePicker.date, completion: { (messageSent, messageRecord, message) in
                
                if !messageSent {
                    self.presentMessageNotSent(messageRecord, message: message)
                }
            })
        })

    }
    
    func presentMessageNotSent(messageRecord: CKRecord, message: Message) {
        let alert = UIAlertController(title: "Failed to Send", message: "There might be something wrong with your connection", preferredStyle: .Alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (_) in
            MessageController.sharedController.deleteMessagesFromCoreData([message])
            MessageController.sharedController.saveContext()
        }
        let resendAction = UIAlertAction(title: "Resend?", style: .Default) { (_) in
            MessageController.sharedController.resaveMessageRecord(messageRecord, completion: { (messageSent) in
                if !messageSent {
                    self.presentMessageNotSent(messageRecord, message: message)
                }
            })
        }
        alert.addAction(cancelAction)
        alert.addAction(resendAction)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    

    
    @IBAction func screenTapped(sender: AnyObject) {
        dateTextField.resignFirstResponder()
      //  dateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)
    }
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        guard let sections = fetchedResultsController.sections else {
            return 1
        }
        return sections.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = fetchedResultsController.sections else {
            return 1
        }
        return sections[section].numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithIdentifier("messageCell", forIndexPath: indexPath) as? ContactTableViewCell, let message = fetchedResultsController.objectAtIndexPath(indexPath) as? Message else {
            return UITableViewCell()
        }
        if message.hasResponded == 1 {
            cell.backgroundColor = UIColor.lightGrayColor()
        }
        cell.updateWith(message)
        
        return cell
    }
   
    
    // Override to support editing the table view.
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            guard let message = MessageController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as? Message else {
                return
            }
            MessageController.sharedController.deleteMessagesFromCoreData([message])
            
            //tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections = MessageController.sharedController.fetchedResultsController.sections else { return nil }
        
        
        guard let phoneNumber = UserController.sharedController.loggedInUser?.phoneNumber else { return "WhereYouApp" }
        
        if sections[section].name == phoneNumber {
            return "WhereYouApp Requests"
        } else {
            return "People want to Know WhereYouApp"
        }
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
        case .Insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
        default: break
        }
        
    }
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        
        switch type {
        case .Delete:
            guard let indexPath = indexPath else { return }
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        case .Insert:
            guard let newIndexPath = newIndexPath else { return }
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
        case .Update:
            guard let indexPath = indexPath else { return }
            
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        case .Move:
            guard let indexPath = indexPath, newIndexPath = newIndexPath else { return }
            
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
        }
        
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }

    
    
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "messageSegue" {
            // Get the new view controller using segue.destinationViewController.
            guard let messageDetailVC = segue.destinationViewController as? MessageDetailViewController,
                let indexPath = tableView.indexPathForSelectedRow else {
                    return
            }
            let message = MessageController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as? Message
            messageDetailVC.message = message
            
            // Pass the selected object to the new view controller.
            
        }
        
    }
    
}
