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
            
            let newContact = User(name: "", phoneNumber: "", imageData: NSData())
            if  let name = CNContactFormatter.stringFromContact(contact, style: .FullName) {
                newContact.name = name
                print(name)
            }
            if let imageData = contact.imageData {
                newContact.imageData = imageData
            }
            
            var phoneNumbers = [String]()
            
            if contact.phoneNumbers.count > 0 {
                phoneNumbers = getMobileFormatedNumber(contact.phoneNumbers)
            } else {
                self.presentContactHasNoMobilePhone(newContact)
                print("no phone number")
                return
            }
            
            // Make sure a number has been extracted from Contacts.
            if phoneNumbers.count < 1 {
                presentContactHasNoMobilePhone(newContact)
                return
            }
            
            var contactPhoneNumber = phoneNumbers[0]
            // If number has a 1 before the area code and phone number remove it.
            if contactPhoneNumber.characters.count > 10 {
                contactPhoneNumber.removeAtIndex(contactPhoneNumber.startIndex)
            }
            
            // Add phone number to new contact.
            newContact.phoneNumber = contactPhoneNumber
            
            guard let  loggedInUser = UserController.sharedController.loggedInUser,
                loggedInUserRecord = loggedInUser.cloudKitRecord else {
                    print("Couldn't get logged in user and/or record")
                    return
            }
            
            // Add contact to Logged In User's contact
            loggedInUser.contacts.append(newContact)
            UserController.sharedController.contacts.append(newContact)
            
            // Check to see if the Contact has an app account and if not ask user to recommend contact to download app
            UserController.sharedController.checkIfContactHasAccount(newContact, completion: { (record) in
                guard let contactRecord = record else {
                    newContact.hasAppAccount = false
                    self.presentNoUserAccount(newContact)
                    UserController.sharedController.saveContext()
                    return
                    
                }
                
                // If User has account add contact reference to User's CKrecord
                let contactReference = CKReference(recordID: contactRecord.recordID, action: .None)
                loggedInUser.contactReferences.append(contactReference)
                loggedInUserRecord[User.contactsKey] = loggedInUser.contactReferences
                
                // Add user to contact's contacts.
                newContact.contactReferences.append(loggedInUser.cloudKitReference!)
                contactRecord[User.contactsKey] = newContact.contactReferences
                
                // Modify both user's records.
                CloudKitManager.cloudKitController.modifyRecords([contactRecord,loggedInUserRecord], perRecordCompletion: { (record, error) in
                    
                    }, completion: { (records, error) in
                        if let error = error {
                            print("Error modifying Contacts. Error: \(error.localizedDescription)")
                            UserController.sharedController.saveContext()
                        } else {
                            // If modifying records are successful present success alert to user.
                            self.presentUserHasAccount(newContact)
                            newContact.hasAppAccount = true
                            UserController.sharedController.saveContext()
                        }
                })
            })
            
        }
    }
    
    // Gets Mobile phone number and fomats it so we can use it as a predicate when searching for User in CloudKit
    func getMobileFormatedNumber(numbers: [CNLabeledValue]) -> [String] {
        
        var phoneNumbers = [String]()
        
        // Find The Mobile Phone Number in Contacts and remove any punctuation and white spacing
        for phoneNumberLabel in numbers {
            if phoneNumberLabel.label != CNLabelPhoneNumberMobile {
                break
            }
            let phoneNumber = phoneNumberLabel.value as! CNPhoneNumber
            let stringPhoneNumber = phoneNumber.stringValue
            let phoneWhite = stringPhoneNumber.lowercaseString.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).joinWithSeparator(" ")
            let noPunc =  phoneWhite.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuationCharacterSet()).joinWithSeparator("")
            let noSpaces = noPunc.stringByReplacingOccurrencesOfString(" ", withString: "")
            
            phoneNumbers.append(noSpaces)
            
        }
        return phoneNumbers
    }
    
    func presentNoUserAccount(newContact: User) {
        let noUserAccountAlert = UIAlertController(title: "\(newContact.name) doesn't have WhereYouApp", message: "Would you like to suggest that they download WhereYouApp", preferredStyle: .Alert)
        
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil)
        let recommendAction = UIAlertAction(title: "Recommend", style: .Default) { (_) in
            
            let messageVC = MFMessageComposeViewController()
            if MFMessageComposeViewController.canSendText() == true {
                messageVC.body = "I'd like you to download WhereYouApp so I can know WhereYouApp"
                messageVC.recipients = [newContact.phoneNumber]
                //  messageVC.messageComposeDelegate = self
                messageVC.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
                messageVC.navigationBar.translucent = false // TODO: - GET THE NAVBAR TO FREAKING BE SOLID.
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
        let alert = UIAlertController(title: "Success" , message: "\(newContact.name) has WhereYouApp", preferredStyle: .Alert)
        let action = UIAlertAction(title: "dismiss", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
            
        })
        
    }
    
    func presentContactHasNoMobilePhone(newContact: User) {
        let alert = UIAlertController(title: "No Mobile Number Found", message: "\(newContact.name)'s number in your Contact's needs to be in mobile field.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "Got It", style: .Default, handler: nil)
        alert.addAction(action)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
            
        })
    }
    
    
    func newContactAdded(notification: NSNotification) {
        self.tableView.reloadData()
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
            cell.userInteractionEnabled = false
            
        }
        cell.textLabel?.text = contact.name
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
    
    /*
     // Override to support editing the table view.
     override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
     if editingStyle == .Delete {
     // Delete the row from the data source
     tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
     } else if editingStyle == .Insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
