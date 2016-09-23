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
    @IBOutlet weak var numberFieldButtomConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonView: UIView!
    @IBOutlet weak var tapPhotoButton: UIButton!
    
    let imagePicker = UIImagePickerController()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupImage()
        numberTextField.delegate = self
        CloudKitManager.cloudKitController.checkIfUserIsLoggedIn { (signedIn) in
            if !signedIn {
                self.presentICloudAlert()
            }
        }
        
        findUsersCloudKitAccountAndRetore { (hasAccount) in }
        numberTextField.delegate = self
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillShowNotification(_:)), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
        
    }
    
    /// When User taps the Submit button it checks if the number entered was formatted correctly and then saves a User record.
    @IBAction func submitButtonTapped(sender: AnyObject) {
        guard let image = self.imageView.image else { return }
        guard let phoneNumber = self.numberTextField.text else {
            self.presentNumberAlert()
            return
        }
        var formatedNumber = NumberController.sharedController.formatNumberFromLoginForRecordName(phoneNumber)
        NumberController.sharedController.checkIfPhoneHasTheRightAmountOfDigits(&formatedNumber) { (isFormattedCorrectly, formatedNumber) in
            if isFormattedCorrectly {
                self.loadingAlert("Creating Your Profile...")
                UserController.sharedController.createUser("", phoneNumber: formatedNumber, image: image, completion: { (success, user) in
                    if success {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.dismissViewControllerAnimated(true, completion: {
                                self.dismissViewControllerAnimated(true, completion: nil)
                            })
                        })
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.dismissViewControllerAnimated(true, completion: {
                                if let user = user {
                                    UserController.sharedController.deleteContactsFromCoreData([user])
                                }
                                self.presentFailedToSave()
                            })
                        })
                    }
                })
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentNumberAlert()
                    return
                })
            }
        }
    }
    
    
    /* When user taps "Already have an account?" it calls findUsersCloudKitAccountAndRetore to check if the iCloud acct has CheckInTime acct
    */
    @IBAction func findAccountButtonTapped(sender: AnyObject) {
        findUsersCloudKitAccountAndRetore { (hasAccount) in
            if !hasAccount {
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentNoAccountFound()
                })
            }
        }
    }
    
    @IBAction func screenTapped(sender: AnyObject) {
        numberTextField.resignFirstResponder()
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
    
    
    /// Checks if the iCloud User has already made an account.
    func findUsersCloudKitAccountAndRetore(completion: (hasAccount: Bool) ->Void) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        CloudKitManager.cloudKitController.checkForCloudKitUserAccount { (hasCloudKitAccount, userRecord) in
            if hasCloudKitAccount {
                guard let userRecord = userRecord else {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    completion(hasAccount: false)
                    return
                }
                self.presentRestoreUser(userRecord, completion: { (restoredUser) in
                    guard let restoredUser = restoredUser else {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        completion(hasAccount: true)
                        return
                    }
                    if restoredUser {
                        self.wantsToRestoreTheirAccount({
                            completion(hasAccount: true)
                            
                        })
                    } else {
                        self.choseToCreateNewAccount(userRecord.recordID, completion: {
                            completion(hasAccount: false)
                        })
                    }
                })
            } else {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                completion(hasAccount: false)
            }
        }
    }
    
    
    
    /// Helper method that deletes the User account if they have an account and want to create a new one.
    func choseToCreateNewAccount(userRecordID: CKRecordID, completion: ()->Void) {
        CloudKitManager.cloudKitController.deleteRecordWithID(userRecordID, completion: { (recordID, error) in
            if let error = error {
                print("Error deleting User's Record. Error: \(error.localizedDescription)")
            }
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            completion()
        })
    }
    
    
    /// Helper method that is performed if the User wants to restore their account on the device.
    func wantsToRestoreTheirAccount(completion: ()->Void) {
        UserController.sharedController.fetchCloudKitContacts({ (hasUsers) in
            if hasUsers {
                MessageController.sharedController.fetchAllMessagesFromCloudKit({
                    print("Messages restored")
                    dispatch_async(dispatch_get_main_queue(), {
                        self.dismissViewControllerAnimated(true, completion: {
                            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                            self.dismissViewControllerAnimated(true, completion: nil)
                            completion()
                        })
                    })
                })
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    self.dismissViewControllerAnimated(true, completion: {
                        self.dismissViewControllerAnimated(true, completion: nil)
                        completion()
                    })
                })
            }
        })
    }
    
    
    
    /// Raises the number textField above the keyboard.
    func keyboardWillShowNotification(notification: NSNotification) {
        if let userInfoDictionary = notification.userInfo, keyboardFrameValue = userInfoDictionary[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardFrame = keyboardFrameValue.CGRectValue()
            UIView.animateWithDuration(0.8, animations: {
                self.numberFieldButtomConstraint.constant = keyboardFrame.size.height-45
                self.imageView.layoutIfNeeded()
                
            })
        }
    }
    
    /// Lowers the number textField before the keyboard is hidden.
    func keyboardWillHide(notification: NSNotification) {
        UIView.animateWithDuration(0.8) {
            
            self.numberFieldButtomConstraint.constant = 15
            self.imageView.layoutIfNeeded()
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            print("Couldn't Get Image from imagePicker 'info'")
            return
        }
        
        imageView.image = image
        setupImage()
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    /// Formats the input from the User
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        if (textField == numberTextField) {
            let newString = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString: string)
            let components = newString.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet().invertedSet)
            let decimalString = components.joinWithSeparator("") as NSString
            let length = decimalString.length
            let hasLeadingOne = length > 0 && decimalString.characterAtIndex(0) == (1 as unichar)
            
            if length == 0 || (length > 10 && !hasLeadingOne) || length > 11 {
                let newLength = (textField.text! as NSString).length + (string as NSString).length - range.length as Int
                
                return (newLength > 10) ? false : true
            }
            var index = 0 as Int
            let formattedString = NSMutableString()
            
            if hasLeadingOne {
                formattedString.appendString("1 ")
                index += 1
            }
            if (length - index) > 3 {
                let areaCode = decimalString.substringWithRange(NSMakeRange(index, 3))
                formattedString.appendFormat("(%@)", areaCode)
                index += 3
            }
            if length - index > 3 {
                let prefix = decimalString.substringWithRange(NSMakeRange(index, 3))
                formattedString.appendFormat("%@-", prefix)
                index += 3
            }
            let remainder = decimalString.substringFromIndex(index)
            formattedString.appendString(remainder)
            textField.text = formattedString as String
            return false
        }
        else {
            return true
        }
    }
    
    /// Presents  message letting the User know that they already have an Account and that it can be restored.
    func presentRestoreUser(record: CKRecord, completion: (restoredUser: Bool?) -> Void) {
        let alert = UIAlertController(title: "We have found a user account linked with your iCloud Account. Would you like to restore it on this device?", message: nil
            , preferredStyle: .Alert)
        let restoreAction = UIAlertAction(title: "Restore", style: .Default) { (_) in
            guard let user = User(record: record) else {
                print("Could not restore user")
                completion(restoredUser: false)
                return
            }
            self.loadingAlert("Restoring User...")
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
        let createNewUserAction = UIAlertAction(title: "Create New User", style: .Default) { (_) in
            completion(restoredUser: false)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (_) in
            completion(restoredUser: nil)
        }
        alert.addAction(createNewUserAction)
        alert.addAction(restoreAction)
        alert.addAction(cancelAction)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    
    
    /// Sets up the titleView with the logo
    func setupView() {
        UINavigationBar.appearance().barTintColor = UIColor ( red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0 )
        let image = UIImage(named: "CheckInTimeTitleWhiteSmall")
        let imageViewImage = UIImageView(image: image)
        
        
        self.navigationItem.titleView = imageViewImage
        UINavigationBar.appearance().barTintColor = UIColor ( red: 0.2078, green: 0.7294, blue: 0.7373, alpha: 1.0 )
        
        buttonView.layer.masksToBounds = true
        buttonView.layer.cornerRadius = 8
        
    }
    
    
    func setupImage() {
        
        let radius = imageView.frame.size.width/2
        self.imageView.layer.masksToBounds = true
        self.imageView.clipsToBounds = true
        self.imageView.layer.cornerRadius = radius
        
    }
    
    /// Presents a loading screen when creating account.
    func loadingAlert(message: String) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
        
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
//        let settingsAction = UIAlertAction(title: "Settings", style: .Default) { (_) -> Void in
//            let settingsUrl = NSURL(string: "prefs:root=CASTLE")
//            if let url = settingsUrl {
//                UIApplication.sharedApplication().openURL(url)
//            }
//        }
//        alert.addAction(settingsAction)
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
    
    func presentFailedToSave() {
        let alert = UIAlertController(title: "We're Sorry. There was a problem saving your account.", message: "You may already have an account with us.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    func presentNoAccountFound() {
        let alert = UIAlertController(title: "No Account Found", message: "It could potentially be a problem with your connection. If you believe this is the case, please try again.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    
}
