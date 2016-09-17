//
//  ContactsTableViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CloudKit
import Contacts
import ContactsUI
import MessageUI
import CoreData

class ContactsTableViewController: UITableViewController, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate, NSFetchedResultsControllerDelegate  {
    
    var contactStore = CNContactStore()
    var fetchedResultsController: NSFetchedResultsController?
    let moc = Stack.sharedStack.managedObjectContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchResultsController()
        setupNavBar()
        checkForContactUpdates()
    }
    
    
    // FetchContacts for ContactTableViewController.
    func setupFetchResultsController() {
        guard let loggedInUser = UserController.sharedController.loggedInUser else {
            return
        }
        
        
        let request = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "phoneNumber != %@", argumentArray: [loggedInUser.phoneNumber])
        request.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.moc, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController?.delegate = self
        
        
        let _ = try? fetchedResultsController?.performFetch()
        
    }
    
    /// Opens the User's Contacts
    @IBAction func addContactsButtonTapped(sender: AnyObject) {
        requestForAccess { (accessGranted) in
            if accessGranted {
                let contactPickerViewController = CNContactPickerViewController()
                contactPickerViewController.delegate = self
                contactPickerViewController.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactImageDataKey, CNContactPhoneNumbersKey]
                self.presentViewController(contactPickerViewController, animated: true, completion: nil)
            }
        }
    }
    
    /// Checks whether or not the User has given the App permission to access their contacts.
    func requestForAccess(completionHandler: (accessGranted: Bool) -> Void) {
        let authorizationStatus = CNContactStore.authorizationStatusForEntityType(CNEntityType.Contacts)
        
        switch authorizationStatus {
        case .Authorized:
            completionHandler(accessGranted: true)
            
        case .Denied, .NotDetermined:
            self.contactStore.requestAccessForEntityType(CNEntityType.Contacts, completionHandler: { (access, accessError) -> Void in
                if access {
                    completionHandler(accessGranted: access)
                }
                else {
                    if authorizationStatus == CNAuthorizationStatus.Denied {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            let message = "\(accessError!.localizedDescription)\n\nPlease allow the app to access your contacts through the Settings."
                            self.showMessage(message)
                        })
                    }
                }
            })
        default:
            completionHandler(accessGranted: false)
        }
    }
    
    
    /// Calls two functions that check if a particular contact has signed up or deleted the App.
    func checkForContactUpdates() {
        UserController.sharedController.checkIfContactsHaveDeletedApp { (haveDeletedApp, updatedUsers) in
            if haveDeletedApp {
                self.presentContactsHaveDeletedApp(updatedUsers!)
            } else {
                print("No one has deleted their app")
                
            }
        }
        UserController.sharedController.checkIfContactsHaveSignedUpForApp { (newAppAcctUsers, updatedUsers) in
            if newAppAcctUsers {
                self.presentNewAppAcctUsers(updatedUsers!)
            } else {
                print("No greyed out contacts have downloaded their app")
            }
        }
        
    }
    
    /// Message that can be customized depending on what is needed to be said.
    func showMessage(alert: String) {
        let alertController = UIAlertController(title: "CheckInTime", message: alert, preferredStyle: UIAlertControllerStyle.Alert)
        let dismissAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) -> Void in
        }
        alertController.addAction(dismissAction)
        self.presentViewController(alertController, animated: true, completion: nil)
        
    }
    
    /// Delegate function that is called when a contact is selected.
    func contactPicker(picker: CNContactPickerViewController, didSelectContact contact: CNContact) {
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) && contact.isKeyAvailable(CNContactImageDataKey) {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            guard let name = CNContactFormatter.stringFromContact(contact, style: .FullName) else {
                return
            }
            let imageData = contact.imageData  ?? UIImagePNGRepresentation(UIImage(named: "profile")!)!
            if contact.phoneNumbers.count > 0 {
                numberFormatAndCheck(contact.phoneNumbers, name: name, completion: { (formattedNumber) in
                    guard let contactPhoneNumber = formattedNumber else { return }
                    self.AddContact(name, contact: contact, contactPhoneNumber: contactPhoneNumber, imageData: imageData)
                })
            } else {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.presentContactHasNoMobilePhone(name)
                print("no phone number")
                return
            }
        }
    }
    
    
    /// Check's if the Contact has a phone number and formats it into a 10 digit number.
    func numberFormatAndCheck(phoneNumbers: [CNLabeledValue], name: String, completion: (formattedNumber: String?) ->Void) {
        let numbers = NumberController.sharedController.getMobileNumberFormatedForUserRecordName(phoneNumbers)
        
        // Make sure a number has been extracted from Contacts.
        if numbers.count < 1 {
            dispatch_async(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.presentContactHasNoMobilePhone(name)
            })
            completion(formattedNumber: nil)
        } else {
            var contactPhoneNumber = numbers[0]
            NumberController.sharedController.checkIfPhoneHasTheRightAmountOfDigits(&contactPhoneNumber, completion: { (isFormattedCorrectly, formatedNumber) in
                if !isFormattedCorrectly {
                    dispatch_async(dispatch_get_main_queue(), {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        self.presentContactHasNoMobilePhone(name)
                    })
                    completion(formattedNumber: nil)
                } else {
                    completion(formattedNumber: formatedNumber)
                }
            })
        }
    }
    
    
        /// Deciphers whether or not the contact is a duplicate or if they are trying to add themselves.
        func AddContact(name: String, contact: CNContact, contactPhoneNumber: String, imageData: NSData) {
            // Add phone number to new contact.
            if contactPhoneNumber == UserController.sharedController.loggedInUser?.phoneNumber {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.presentTryingToAddYourselfAlert()
                return
            }
            UserController.sharedController.checkForDuplicateContact(contactPhoneNumber, completion: { (hasContactAlready, isCKContact) in
                if hasContactAlready && isCKContact {
                    dispatch_async(dispatch_get_main_queue(), {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        self.presenthasContactAlreadyAlert(name)
                        return
                    })
                } else if hasContactAlready && !isCKContact {
                    UserController.sharedController.fetchCloudKitUserWithNumber(contactPhoneNumber, completion: { (contact) in
                        guard let contact = contact else {
                            dispatch_async(dispatch_get_main_queue(), {
                                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                                self.presentFailedToAddContact()
                            })
                            return
                        }
                        contact.name = name
                        UserController.sharedController.saveNewContactToCloudKit(contact, contactRecord: contact.cloudKitRecord!, completion: { (savedSuccessfully) in
                            if savedSuccessfully {
                                print("Saved Contact Successfully to CloudKit")
                                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                                self.presentAddedContactSuccessfully()
                                return
                            } else {
                                print("Failed to save contact to cloudkit. Try again.")
                                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                                self.presentFailedToAddContact()
                                return
                            }
                        })
                    })
                } else {
                    // Create Contact and Save Contact to CoreData
                    self.createNewContactAndSave(name, phoneNumber: contactPhoneNumber, imageData: imageData)
                }
            })
        }
    
    
    
    /// If the User doesn't have this contact in CoreData or CloudKit, create a new contact and save to User's Contacts property.
    func createNewContactAndSave(name: String, phoneNumber: String, imageData: NSData) {
        MessageController.sharedController.saveContext()
        // Check to see if the Contact has an app account and if not ask user to recommend contact to download app
        UserController.sharedController.checkIfContactHasAccount(phoneNumber, completion: { (record) in
            guard let contactRecord = record else {
                let newContact = User(name: name, phoneNumber: phoneNumber, imageData: imageData, hasAppAccount: false)
                newContact.hasAppAccount = false
                // Add contact to Logged In User's contact
                UserController.sharedController.saveContext()
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    self.presentNoUserAccount(newContact)
                })
                return
            }
            guard let newContact = User(record: contactRecord) else {
                self.presentFailedToAddContact()
                return
            }
            newContact.name = name
            UserController.sharedController.saveNewContactToCloudKit(newContact, contactRecord: contactRecord, completion: { (savedSuccessfully) in
                if savedSuccessfully {
                    dispatch_async(dispatch_get_main_queue(), {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        self.presentUserHasAccount(newContact)
                    })
                    
                }
            })
        })
    }
    
    
    /// Sets titile Icon and color scheme.
    func setupNavBar() {
        UINavigationBar.appearance().barTintColor = UIColor ( red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0 )
        let image = UIImage(named: "ContactsTitleSmall")
        let imageView = UIImageView(image: image)
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .Plain, target: nil, action: nil)
        
        self.navigationItem.titleView = imageView
        UINavigationBar.appearance().barTintColor = UIColor ( red: 0.2078, green: 0.7294, blue: 0.7373, alpha: 1.0 )
    }
    
    
    /// Presents a loading alert to let the user know that it is adding a contact.
    func loadingAlert() {
        let alert = UIAlertController(title: nil, message: "Adding Contact...", preferredStyle: .Alert)
        
        alert.view.tintColor = UIColor.blackColor()
        let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRectMake(10, 5, 50, 50)) as UIActivityIndicatorView
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.Gray
        loadingIndicator.startAnimating();
        
        alert.view.addSubview(loadingIndicator)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
            
        })
    }
    
    /// Tell the User when their contacts have deleted CheckInTime
    func presentContactsHaveDeletedApp(deletedContacts: [User]) {
        
        let names = deletedContacts.flatMap({$0.name})
        let formatedNames = names.joinWithSeparator(" ")
        
        let alert = UIAlertController(title: "\(formatedNames) have deleted their account", message: nil, preferredStyle: .Alert)
        let okAction = UIAlertAction(title: "OK", style: .Cancel) { (_) in
            self.tableView.reloadData()
        }
        alert.addAction(okAction)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    /// Dismisses the Messages app and comes back to CheckInTime
    func messageComposeViewController(controller: MFMessageComposeViewController, didFinishWithResult result: MessageComposeResult) {
        
        self.dismissViewControllerAnimated(true, completion: nil)
        self.becomeFirstResponder()
    }
    
    /// Tell the User when their contacts have downloaded CheckInTime
    func presentNewAppAcctUsers(updatedUsers: [User]) {
        
        let names = updatedUsers.flatMap({$0.name})
        let newNames = names.joinWithSeparator("")
        
        let newAppAcctsAlert = UIAlertController(title: "\(newNames) downloaded CheckInTime", message: "You can now send CheckInTimes to them and they can send CheckInTimes to you.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "Sounds Good", style: .Cancel, handler: nil)
        newAppAcctsAlert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(newAppAcctsAlert, animated: true, completion: nil)
        })
    }
    
    
    
    
    // Takes in an array and formats it grammatically to present to user.
    func formatNames(names: [String] -> String) {
        
        
        
        
    }
    
    // Tell user that something went wrong when adding Contact
    func presentFailedToAddContact() {
        let alert = UIAlertController(title: "Something Went Wrong When Adding Contact. Please Try Again.", message: nil, preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    // Tell user that they Successfully Added Contact
    func presentAddedContactSuccessfully() {
        let alert = UIAlertController(title: "Successfully Added Contact", message: nil, preferredStyle: .Alert)
        let action = UIAlertAction(title: "Sweet", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
        
    }
    
    // Tells user that the Contact they are tyring to add is already in their contacts list.
    func presenthasContactAlreadyAlert(name: String) {
        let alert = UIAlertController(title: "You already have \(name) in your contacts", message: nil, preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
        
    }
    
    // Tells User that they can't add themselves as a Contact.
    func presentTryingToAddYourselfAlert() {
        let alert = UIAlertController(title: "You have selected yourself as a Contact", message: "You cant add yourself at this time", preferredStyle: .Alert)
        
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
        
        
    }
    
    /// Tells the User that the contact they selected doesn't have the app and that they can recommend it to them or not.
    func presentNoUserAccount(newContact: User) {
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(newContact.phoneNumber)
        
        let noUserAccountAlert = UIAlertController(title: "\(newContact.name ?? formatedPhoneNumber) doesn't have CheckInTime", message: "Would you like to suggest that they download CheckInTime?", preferredStyle: .Alert)
        
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Cancel) { (_) in
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        let recommendAction = UIAlertAction(title: "Recommend", style: .Default) { (_) in
            
            let messageVC = MFMessageComposeViewController()
            if MFMessageComposeViewController.canSendText() == true {
                messageVC.body = "I'd like you to download CheckInTime so you can check in with me."
                messageVC.recipients = [newContact.phoneNumber]
                messageVC.messageComposeDelegate = self
                //  messageVC.messageComposeDelegate = self
                messageVC.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
                messageVC.navigationBar.translucent = false
                self.presentViewController(messageVC, animated: true, completion: {
                    noUserAccountAlert.view.tintColor = UIColor ( red: 0.5004, green: 1.0, blue: 0.556, alpha: 1.0 )
                })
            } else {
                self.showMessage("We're sorry there was a problem accessing Messages.")
            }
        }
        noUserAccountAlert.addAction(dismissAction)
        noUserAccountAlert.addAction(recommendAction)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(noUserAccountAlert, animated: true, completion: nil)
            
        })
        
    }
    
    
    /// Tells the User that the Contact they selected has the App account.
    func presentUserHasAccount(newContact: User) {
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(newContact.phoneNumber)
        
        let alert = UIAlertController(title: "Success" , message: "\(newContact.name ?? formatedPhoneNumber) has CheckInTime", preferredStyle: .Alert)
        let action = UIAlertAction(title: "Awesome", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
            
        })
    }
    
    /// Tells the User that the Contact has no number saved.
    func presentContactHasNoMobilePhone(name: String) {
        let alert = UIAlertController(title: "No Number Found", message: "\(name)'s number in your Contact's needs to be at least 10 digits and no longer than 11.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "Got It", style: .Default, handler: nil)
        alert.addAction(action)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    
    // MARK: - Table view data source
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.fetchedResultsController?.fetchedObjects?.count ?? 0
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("contactCell", forIndexPath: indexPath)
        
        guard let contact = self.fetchedResultsController?.objectAtIndexPath(indexPath) else {
            return UITableViewCell()
        }
        if contact.hasAppAccount == false {
            
            cell.textLabel?.textColor = UIColor.lightGrayColor()
        } else {
            cell.textLabel?.textColor = UIColor ( red: 0.1882, green: 0.2275, blue: 0.3137, alpha: 1.0 )
        }
        
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(contact.phoneNumber)
        
        if contact.name == contact.phoneNumber {
            cell.textLabel?.text = formatedPhoneNumber
        } else {
            cell.textLabel?.text = contact.name ?? formatedPhoneNumber
        }
        return cell
    }
    
    
    
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            guard let contact = fetchedResultsController?.objectAtIndexPath(indexPath) as? User else {
                return
                
            }
            UserController.sharedController.deleteContactFromCloudKit(contact)
            
            
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
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
        
        if segue.identifier == "contactSegue" {
            // Get the new view controller using segue.destinationViewController.
            guard let contactDetailVC = segue.destinationViewController as? ContactDetailViewController,
                let indexPath = tableView.indexPathForSelectedRow, contact = fetchedResultsController?.objectAtIndexPath(indexPath) as? User else {
                    return
            }
            
            
            
            contactDetailVC.contact = contact
            // Pass the selected object to the new view controller.
        }
    }
    
    
}
