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

class ContactsTableViewController: UITableViewController, CNContactPickerDelegate  {
    
    var contactStore = CNContactStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(self.newContactAdded(_:)), name: NewContactAdded, object: nil)
        UserController.sharedController.checkIfContactsHaveDeletedApp { (haveDeletedApp, updatedUsers) in
            if haveDeletedApp {
                self.presentContactsHaveDeletedApp(updatedUsers!)
            }
        }
        UserController.sharedController.checkIfContactsHaveSignedUpForApp { (newAppAcctUsers, updatedUsers) in
            if newAppAcctUsers {
                UserController.sharedController.contacts = UserController.sharedController.contacts
                self.presentNewAppAcctUsers(updatedUsers!)
            } else {
                print("no new app users from contacts")
            }
        }
    }
    
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
    
    func showMessage(alert: String) {
        let alertController = UIAlertController(title: "WhereYouApp", message: alert, preferredStyle: UIAlertControllerStyle.Alert)
        
        let dismissAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) -> Void in
        }
        
        alertController.addAction(dismissAction)
        self.presentViewController(alertController, animated: true, completion: nil)
        
    }
    
    func contactPicker(picker: CNContactPickerViewController, didSelectContact contact: CNContact) {
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) && contact.isKeyAvailable(CNContactImageDataKey) {
            
            guard let name = CNContactFormatter.stringFromContact(contact, style: .FullName) else {
                return
                
            }
            let imageData = contact.imageData  ?? UIImagePNGRepresentation(UIImage(named: "profile")!)!
            
            var phoneNumbers = [String]()
            
            if contact.phoneNumbers.count > 0 {
                phoneNumbers = NumberController.sharedController.getiPhoneNumberFormatedForUserRecordName(contact.phoneNumbers)
            } else {
                self.presentContactHasNoiPhone(name)
                print("no phone number")
                return
            }
            // Make sure a number has been extracted from Contacts.
            if phoneNumbers.count < 1 {
                presentContactHasNoiPhone(name)
                return
            }
            var contactPhoneNumber = phoneNumbers[0]
            NumberController.sharedController.checkIfPhoneHasTheRightAmountOfDigits(&contactPhoneNumber, completion: { (isFormattedCorrectly, formatedNumber) in
                if !isFormattedCorrectly {
                    self.presentContactHasNoiPhone(name)
                    return
                }
            })
            // Add phone number to new contact.
            let phoneNumber = contactPhoneNumber
            if phoneNumber == UserController.sharedController.loggedInUser?.phoneNumber {
                self.presentTryingToAddYourselfAlert()
                return
            }
            UserController.sharedController.checkForDuplicateContact(phoneNumber, completion: { (hasContactAlready, isCKContact) in
                if hasContactAlready && isCKContact {
                    self.presenthasContactAlreadyAlert(name)
                    return
                } else if hasContactAlready && !isCKContact {
                    UserController.sharedController.fetchCloudKitUserWithNumber(phoneNumber, completion: { (contact) in
                        guard let contact = contact else {
                            return
                        }
                        UserController.sharedController.saveNewContactToCloudKit(contact, contactRecord: contact.cloudKitRecord!, completion: { (savedSuccessfully) in
                            if savedSuccessfully {
                                print("Saved Contact Successfully to CloudKit")
                                self.presentAddedContactSuccessfully()
                                return
                            } else {
                                print("Failed to save contact to cloudkit. Try again.")
                                self.presentFailedToAddContact()
                                return
                            }
                        })
                        
                    })
                    
                } else {
                    // Create Contact and Save Contact to CoreData
                    let newContact = User(name: name, phoneNumber: phoneNumber, imageData: imageData, hasAppAccount: false)
                    MessageController.sharedController.saveContext()
                    guard let  loggedInUser = UserController.sharedController.loggedInUser else {                            print("Couldn't get logged in user and/or record")
                        return
                    }
                    // Check to see if the Contact has an app account and if not ask user to recommend contact to download app
                    UserController.sharedController.checkIfContactHasAccount(newContact, completion: { (record) in
                        guard let contactRecord = record else {
                            newContact.hasAppAccount = false
                            // Add contact to Logged In User's contact
                            loggedInUser.contacts.append(newContact)
                            
                            UserController.sharedController.addContactAndOrderList(newContact)
                            UserController.sharedController.saveContext()
                            
                            self.presentNoUserAccount(newContact)
                            return
                        }
                        
                        UserController.sharedController.saveNewContactToCloudKit(newContact, contactRecord: contactRecord, completion: { (savedSuccessfully) in
                            if savedSuccessfully {
                                self.presentUserHasAccount(newContact)
                            }
                        })
                    })
                }
            })
        }
    }
    
   
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
    
      
    ///
    func presentNewAppAcctUsers(updatedUsers: [User]) {
        
        let names = updatedUsers.flatMap({$0.name})
        let newNames = names.joinWithSeparator("")
        
        let newAppAcctsAlert = UIAlertController(title: "\(newNames) downloaded CheckInTime", message: "You can now set CheckIn Times for them or Check In Time with them.", preferredStyle: .Alert)
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
    func presentNoUserAccount(newContact: User) {
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(newContact.phoneNumber)

        let noUserAccountAlert = UIAlertController(title: "\(newContact.name ?? formatedPhoneNumber) doesn't have WhereYouApp", message: "Would you like to suggest that they download WhereYouApp", preferredStyle: .Alert)
        
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
    
    func presentUserHasAccount(newContact: User) {
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(newContact.phoneNumber)

        let alert = UIAlertController(title: "Success" , message: "\(newContact.name ?? formatedPhoneNumber) has WhereYouApp", preferredStyle: .Alert)
        let action = UIAlertAction(title: "Awesome", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
            
        })
        
    }
    
    func presentContactHasNoiPhone(name: String) {
        let alert = UIAlertController(title: "No iPhone Number Found", message: "\(name)'s number in your Contact's needs to be in iPhone field and needs to be no more than 11 numbers long.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "Got It", style: .Default, handler: nil)
        alert.addAction(action)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
            
        })
    }
    
    func newContactAdded(notification: NSNotification){
        dispatch_async(dispatch_get_main_queue(), {
            self.tableView.reloadData()
        })
        
    }
    
    // MARK: - Table view data source
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        
        return UserController.sharedController.contacts.count
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("contactCell", forIndexPath: indexPath)
        
        let contact = UserController.sharedController.contacts[indexPath.row]
        if contact.hasAppAccount == false {
            
            cell.textLabel?.textColor = UIColor.lightGrayColor()
        }
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(contact.phoneNumber)

        cell.textLabel?.text = contact.name ?? formatedPhoneNumber
        // Configure the cell...
        
        return cell
    }
    
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            let contact = UserController.sharedController.contacts[indexPath.row]
            UserController.sharedController.deleteContactFromCloudKit(contact)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "contactSegue" {
            // Get the new view controller using segue.destinationViewController.
            guard let contactDetailVC = segue.destinationViewController as? ContactDetailViewController,
                let indexPath = tableView.indexPathForSelectedRow else {
                    return
            }
            
            let contact = UserController.sharedController.contacts[indexPath.row]
            
            contactDetailVC.contact = contact
            // Pass the selected object to the new view controller.
        }
    }
    
    
}
