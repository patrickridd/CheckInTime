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
    @IBOutlet weak var numberTextField: UITextField!
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBar()
        numberTextField.delegate = self
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
        
        
        
        
        guard let image = self.imageView.image else {
            return
        }
        guard let phoneNumber = self.numberTextField.text else {
            self.presentNumberAlert()
            return
        }
        var formatedNumber = NumberController.sharedController.formatNumberFromLoginForRecordName(phoneNumber)
        NumberController.sharedController.checkIfPhoneHasTheRightAmountOfDigits(&formatedNumber) { (isFormattedCorrectly, formatedNumber) in
            if isFormattedCorrectly {
                self.loadingAlert()
                
                
                
                UserController.sharedController.createUser("", phoneNumber: formatedNumber, image: image) {
                    dispatch_async(dispatch_get_main_queue(), {
                        
                        self.dismissViewControllerAnimated(true, completion: { 
                            self.dismissViewControllerAnimated(true, completion: nil)
                            let messageListTVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("messageList") as! MessageListTableViewController
                            self.navigationController?.pushViewController(messageListTVC, animated: true)
                        })
                    })
                    
                }
                
            } else {
                self.presentNumberAlert()
                return
            }
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
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view.bounds
            // this is the center of the screen currently but it can be any point in the view
            
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
    
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool
    {
        if (textField == numberTextField)
        {
            let newString = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString: string)
            let components = newString.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet().invertedSet)
            
            let decimalString = components.joinWithSeparator("") as NSString
            let length = decimalString.length
            let hasLeadingOne = length > 0 && decimalString.characterAtIndex(0) == (1 as unichar)
            
            if length == 0 || (length > 10 && !hasLeadingOne) || length > 11
            {
                let newLength = (textField.text! as NSString).length + (string as NSString).length - range.length as Int
                
                return (newLength > 10) ? false : true
            }
            var index = 0 as Int
            let formattedString = NSMutableString()
            
            if hasLeadingOne
            {
                formattedString.appendString("1 ")
                index += 1
            }
            if (length - index) > 3
            {
                let areaCode = decimalString.substringWithRange(NSMakeRange(index, 3))
                formattedString.appendFormat("(%@)", areaCode)
                index += 3
            }
            if length - index > 3
            {
                let prefix = decimalString.substringWithRange(NSMakeRange(index, 3))
                formattedString.appendFormat("%@-", prefix)
                index += 3
            }
            
            let remainder = decimalString.substringFromIndex(index)
            formattedString.appendString(remainder)
            textField.text = formattedString as String
            return false
        }
        else
        {
            return true
        }
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
            user.name = ""
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
    
    /// Sets up the titleView with the logo
    func setupNavBar() {
        UINavigationBar.appearance().barTintColor = UIColor ( red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0 )
        let image = UIImage(named: "CheckInTimeTitle")
        let imageView = UIImageView(image: image)
        
        self.navigationItem.titleView = imageView
    }

    
    /// Presents a loading screen when creating account.
    func loadingAlert() {
        let alert = UIAlertController(title: nil, message: "Creating Your Profile...", preferredStyle: .Alert)
        
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
    
    /// Alerts to User that they need to sign into iCloud
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
