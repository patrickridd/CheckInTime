//
//  ContactDetailViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CoreData

class ContactDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    
    
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
        setupFetchController(contact)
        
        dateTextField.inputView = dueDatePicker
        updateWith(contact)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // self.navigationController?.tabBarController?.
    }
    
    func updateWith(contact: User) {
        self.contactImage.image = contact.photo
        self.nameLabel.text = contact.name
        self.numberLabel.text = contact.phoneNumber
        
        
    }
    
    
    func setupFetchController(contact: User) {
        
        let request = NSFetchRequest(entityName: "Message")
        let descriptor = NSSortDescriptor(key: "timeSent", ascending: true)
        request.sortDescriptors = [descriptor]
        let receiverPredicate = NSPredicate(format: "receiver == %@", argumentArray: [contact])
        let senderPredicate = NSPredicate(format: "sender == %@", argumentArray: [contact])
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [receiverPredicate,senderPredicate])
        request.predicate = compoundPredicate
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "receiver", cacheName: nil  )
        
        let _ = try? fetchedResultsController.performFetch()
        
        
    }
    
    @IBAction func whereYouAppButtonTapped(sender: AnyObject) {
        
        
        guard let sender = UserController.sharedController.loggedInUser,
            receiver = contact else {
                print("No logged in user or contact")
                return
        }
        dateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)
        
        MessageController.sharedController.createMessage(sender, receiver: receiver, timeDue: dueDatePicker.date)
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
            MessageController.sharedController.deleteMessage(message)
            
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
