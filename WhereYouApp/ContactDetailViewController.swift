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

class ContactDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate {
    
    
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
    @IBOutlet var dueDatePicker: UIDatePicker!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var profileViewBox: UIView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var editButtonLabel: UIBarButtonItem!
    @IBOutlet weak var bottomDateTextField: NSLayoutConstraint!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nameTextField.delegate = self
        guard let contact = contact else {
            return
        }
        if contact.hasAppAccount == false {
            self.presentNoUserAccount(contact)
        }
        
        setupFetchController(contact)
        setupView()
        setupImage()
        fetchedResultsController.delegate = self
        dateTextField.inputView = dueDatePicker
        updateWith(contact)
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(self.updatedMessage(_:)), name: UpdatedMessages, object: nil)
    }
    
    
    func updatedMessage(notification: NSNotification){
        self.tableView.reloadData()
    }
    
    func updateWith(contact: User) {
        
        let formattedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(contact.phoneNumber)
        
        self.contactImage.image = contact.photo
        if contact.name == contact.phoneNumber {
            self.nameLabel.text = formattedPhoneNumber
        } else {
            self.nameLabel.text = contact.name ?? formattedPhoneNumber
        }
    }
    
    func setupFetchController(contact: User) {
        let request = NSFetchRequest(entityName: "Message")
        let descriptor = NSSortDescriptor(key: "timeDue", ascending: false)
        let descriptorSenderID = NSSortDescriptor(key: "senderID", ascending: false)
        let sortDescriptorHasResponded = NSSortDescriptor(key: "hasResponded", ascending: true)
        
        request.sortDescriptors = [descriptorSenderID, sortDescriptorHasResponded, descriptor]
        let receiverPredicate = NSPredicate(format: "receiver == %@", argumentArray: [contact])
        let senderPredicate = NSPredicate(format: "sender == %@", argumentArray: [contact])
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [receiverPredicate,senderPredicate])
        request.predicate = compoundPredicate
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "senderID" , cacheName: nil  )
        
        let _ = try? fetchedResultsController.performFetch()
        
    }
    
    @IBAction func editButtonTappedWithSender(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue(), {
            if self.editButtonLabel.title == "Edit Name" {
                self.nameLabel.hidden = true
                self.nameTextField.hidden = false
                self.nameTextField.enabled = true
                self.nameTextField.text = ""
                self.nameTextField.placeholder = "Edit name..."
                self.nameTextField.borderStyle = .RoundedRect
                self.editButtonLabel.title = "Save"
                self.editButtonLabel.tintColor = UIColor ( red: 1.0, green: 0.1629, blue: 0.4057, alpha: 1.0 )
            } else {
                if let text = self.nameTextField.text where text.characters.count > 0  {
                    self.nameLabel.text = text
                }
                self.nameLabel.hidden = false
                self.nameTextField.text = ""
                self.nameTextField.placeholder = ""
                self.nameTextField.borderStyle = .None
                self.nameTextField.hidden = true
                self.nameTextField.enabled = false
                self.editButtonLabel.title = "Edit Name"
                self.contact?.name = self.nameLabel.text
                
                UserController.sharedController.saveContext()
                self.editButtonLabel.tintColor = UIColor.whiteColor()
                self.tableView.reloadData()
            }
        })
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        return nameTextField.resignFirstResponder()
    }
    
    /// Presents to the user that the contact they have chosen doesn't have the App
    func presentNoUserAccount(newContact: User) {
        let noUserAccountAlert = UIAlertController(title: "\(newContact.name ?? newContact.phoneNumber) doesn't have CheckInTime", message: "Would you like to suggest that they download CheckInTime", preferredStyle: .Alert)
        
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil)
        let recommendAction = UIAlertAction(title: "Recommend", style: .Default) { (_) in
            
            let messageVC = MFMessageComposeViewController()
            if MFMessageComposeViewController.canSendText() == true {
                messageVC.body = "I'd like you to download CheckInTime so you can Check In with me"
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
    
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        dateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)
        dateTextField.resignFirstResponder()
        if gestureRecognizer is UITapGestureRecognizer {
            let location = touch.locationInView(tableView)
            return (tableView.indexPathForRowAtPoint(location) == nil)
        }
        return true
    }
    
    @IBAction func SendCheckInTimeWithSender(sender: AnyObject) {
        guard let sender = UserController.sharedController.loggedInUser,
            receiver = contact else {
                return
        }
        if receiver.hasAppAccount == 0 {
            self.presentNoUserAccount(receiver)
            return
        }
        if dueDatePicker.date.timeIntervalSince1970+5 < NSDate().timeIntervalSince1970 {
            self.presentDateHasToBeInFuture()
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
    
    /// Tells user that they can't sent CheckInTimes before the present time.
    func presentDateHasToBeInFuture() {
            let alert = UIAlertController(title: "Time Conflict", message: "The CheckInTime can't be before the current time.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(action)
        self.navigationController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    /// Tells User that the message couldn't be sent.
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
    
 
    
    @IBAction func screenTappedWithSender(sender: AnyObject) {
        dateTextField.resignFirstResponder()
        //  dateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)
    }
    
    func setupView() {
        nameTextField.hidden = true
        nameLabel.layer.masksToBounds = true
        nameLabel.layer.cornerRadius = 5
        nameTextField.enabled = false
        //  UINavigationBar.appearance().barTintColor = UIColor ( red: 0.2078, green: 0.7294, blue: 0.7373, alpha: 1.0 )
        profileViewBox.layer.masksToBounds = true
        profileViewBox.layer.cornerRadius = 8
        // editButtonLabel.tintColor = UIColor ( red: 0.1882, green: 0.2275, blue: 0.3137, alpha: 1.0 )
        
        if contact?.hasAppAccount == 1 {
            let iconImage = UIImage(named: "ContactDetailIcon2")
            let imageView = UIImageView(image: iconImage)
            self.navigationItem.titleView = imageView
        } else {
            let iconImage = UIImage(named: "doesntHaveApp2")
            let imageView = UIImageView(image: iconImage)
            self.navigationItem.titleView = imageView
        }
        
    }
    
    func setupImage() {
        
//        let radius = self.contactImage.frame.size.height/2
//        self.contactImage.layer.masksToBounds = true
//        self.contactImage.layer.cornerRadius = radius
//        self.contactImage.clipsToBounds = true
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
        guard let cell = tableView.dequeueReusableCellWithIdentifier("messageCell", forIndexPath: indexPath) as? ContactDetailTableViewCell, let message = fetchedResultsController.objectAtIndexPath(indexPath) as? Message else {
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
            MessageController.sharedController.deleteMessagesFromCoreData([message])
            
        }
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections = MessageController.sharedController.fetchedResultsController.sections,
            user = UserController.sharedController.loggedInUser else {
                return nil
        }
        
        if sections[section].name == user.phoneNumber {
            return "Sent"
        } else {
            return "Received"
        }
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else {
            return
        }
        
        headerView.textLabel?.textColor = UIColor ( red: 0.2078, green: 0.7294, blue: 0.7373, alpha: 1.0 )
        headerView.textLabel?.font = UIFont(name: "Helvetica", size: 15.0)
        headerView.contentView.backgroundColor = UIColor ( red: 0.1882, green: 0.2275, blue: 0.3137, alpha: 1.0 )
        headerView.textLabel?.textAlignment = .Center
    }
    
    
    
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
            let message = fetchedResultsController.objectAtIndexPath(indexPath) as? Message
            messageDetailVC.message = message
            
            // Pass the selected object to the new view controller.
            
        }
        
    }
    
}
