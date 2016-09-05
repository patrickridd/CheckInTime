//
//  MessageTesterViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/31/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CloudKit

class MessageTesterViewController: UIViewController {

    @IBOutlet var dueDatePicker: UIDatePicker!
    @IBOutlet weak var dueDateTextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        dueDateTextField.inputView = dueDatePicker
        guard let text = dueDateTextField.text else {
            print("nothing in textfield")
            return
        }
        print(text)
    }
        let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    @IBAction func cancelButtonTapped(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
        
    }

    @IBAction func sendButtonTapped(sender: AnyObject) {
        
        dueDateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)

        
        guard let user = UserController.sharedController.loggedInUser else {
            return
        }
        
        UserController.sharedController.fetchContactsFromCoreData { (contacts) in
            if contacts.count == 0 {
                let predicate = NSPredicate(format: "name != %@", argumentArray: [user.name])
                
                CloudKitManager.cloudKitController.fetchRecordsWithType("User", predicate: predicate, recordFetchedBlock: { (record) in
                    guard let receiver = User(record: record), let loggedInUser =  UserController.sharedController.loggedInUser else {
                        return
                    }
                    loggedInUser.contacts.append(receiver)

                    UserController.sharedController.saveContext()
                    
                    guard let receiverRecord = receiver.cloudKitRecord, loggedInUserRecord = loggedInUser.cloudKitRecord else {
                    print("Couldn't get CKRecord from NSData")
                        return
                    }
                    let reference = CKReference(recordID: receiverRecord.recordID, action: .None)
                    
                    loggedInUser.contactReferences.append(reference)
                    loggedInUserRecord[User.contactsKey] = loggedInUser.contactReferences
                    receiver.contactReferences.append(loggedInUser.cloudKitReference!)
                    receiverRecord[User.contactsKey] = receiver.contactReferences
                    CloudKitManager.cloudKitController.modifyRecords([loggedInUserRecord,receiverRecord], perRecordCompletion: { (record, error) in
                        
                        
                        }, completion: { (records, error) in
                            if let error = error {
                                print("Error adding contact to user record. Error: \(error.localizedDescription)")
                            } else {
                                print("Successfully added Contact to user record")
                            }
                            
                    })
                   
                    MessageController.sharedController.createMessage(loggedInUser, receiver: receiver, timeDue: self.dueDatePicker.date)
                    
                }) { (records, error) in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
            } else {
                guard let receiver = contacts.first else { return }
                UserController.sharedController.fetchContactsFromCoreData({_ in 
                    
                })
                
                MessageController.sharedController.createMessage(user, receiver: receiver, timeDue: NSDate())
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            
        }
    }
    
    @IBAction func screenTapped(sender: AnyObject) {
        dueDateTextField.resignFirstResponder()
        dueDateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)

    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
