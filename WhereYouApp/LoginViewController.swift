//
//  LoginViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CloudKit

class LoginViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var numberTextField: UITextField!
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        CloudKitManager.cloudKitController.checkIfUserIsLoggedIn { (signedIn) in
            if !signedIn {
                self.presentICloudAlert()
            }
        }
        
       CloudKitManager.cloudKitController.checkForCloudKitUserAccount { (hasCloudKitAccount, userRecord) in
        if hasCloudKitAccount {
            self.presentRestoreUser(userRecord!, completion: { (restoredUser) in
                if restoredUser {
                    UserController.sharedController.fetchCloudKitContacts({ (hasUsers) in
                        if hasUsers {
                            MessageController.sharedController.fetchAllMessagesFromCloudKit({
                                print("Messages restored")
                                        dispatch_async(dispatch_get_main_queue(), {
                                            self.dismissViewControllerAnimated(true, completion: nil)

                                        })
                            })
                            
                        } else {
                            dispatch_async(dispatch_get_main_queue(), {
                                self.dismissViewControllerAnimated(true, completion: nil)
                                
                            })
                        }
                
                    })
                }
            })
        }
    }
        numberTextField.delegate = self
    }

    @IBAction func submitButtonTapped(sender: AnyObject) {
        guard let image = imageView.image else {
            return
        }
        
            guard let phoneNumber = numberTextField.text where phoneNumber.characters.count >= 10 else {
                self.presentNumberAlert()
                return
        }
        
        UserController.sharedController.createUser("", phoneNumber: phoneNumber, image: image) {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    @IBAction func changePhotoButtonTapped(sender: AnyObject) {
        imagePicker.delegate = self
        let alert = UIAlertController(title: "Choose Image Source", message: nil, preferredStyle: .ActionSheet)
        
        let photoLibraryAction = UIAlertAction(title: "Photo Library", style: .Default) { (_) in
            self.imagePicker.sourceType = .PhotoLibrary
            self.presentViewController(self.imagePicker, animated: true, completion: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alert.addAction(photoLibraryAction)
        alert.addAction(cancelAction)
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentViewController(alert, animated: true, completion: nil)

        })
    }
    
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            print("Couldn't Get Image from imagePicker 'info'")
            return
        }
        
        imageView.image = image
        dismissViewControllerAnimated(true, completion: nil)
    }


    
    func presentRestoreUser(record: CKRecord, completion: (restoredUser: Bool) -> Void) {
        let alert = UIAlertController(title: "You have an existing User account in CloudKit, would you like to restore it on this device?", message: nil
        , preferredStyle: .Alert)
        
        let restoreAction = UIAlertAction(title: "Restore", style: .Default) { (_) in
            guard let user = User(record: record) else {
                print("Could not restore user")
                completion(restoredUser: false)
                return
            }
            UserController.sharedController.loggedInUser = user
            UserController.sharedController.loggedInUser?.cloudKitRecord = record
            UserController.sharedController.saveContext()
            print("Restored User")
            CloudKitManager.cloudKitController.fetchSubscription("My Messages", completion: { (subscription, error) in
                guard let subscription = subscription else {
                    MessageController.sharedController.subscribeToMessages()
                    completion(restoredUser: true)
                    return
                }
                print("Subcribed to Subscription: \(subscription)")
                completion(restoredUser: true)

            })
        }
        let cancelAction = UIAlertAction(title: "Create New User", style: .Cancel) { (_) in
            completion(restoredUser: false)
        }
        alert.addAction(restoreAction)
        alert.addAction(cancelAction)
            dispatch_async(dispatch_get_main_queue(), {
                self.presentViewController(alert, animated: true, completion: nil)
        })

    }
    
    func presentICloudAlert() {

        let alert = UIAlertController(title: "Not Signed Into iCloud Account", message:"To send and receive messages you need to be signed into your cloudkit account. Sign in and realaunch app", preferredStyle: .Alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Default, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .Default) { (_) -> Void in
            let settingsUrl = NSURL(string: "prefs:root=CASTLE")
            if let url = settingsUrl {
                UIApplication.sharedApplication().openURL(url)
                
            }
        }
        alert.addAction(settingsAction)
        alert.addAction(dismissAction)
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        return numberTextField.resignFirstResponder()
    }

    func presentNameAlert() {
        let alert = UIAlertController(title: nil, message: "Name needs one character or more", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    func presentNumberAlert() {
        let alert = UIAlertController(title: nil, message: "Phone Number needs to be 10 digits", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentViewController(alert, animated: true, completion: nil)
        })
    }

    
}
