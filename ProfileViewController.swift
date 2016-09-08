//
//  ProfileViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var loggedInUser: User?
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let user = loggedInUser else {
            return
        }
        imageView.image = user.photo
        
    }
    
    @IBAction func imageTapped(sender: AnyObject) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        let actionSheet = UIAlertController(title: "Choose an Image Source", message: nil, preferredStyle: .ActionSheet)
        
        
        imagePicker.delegate = self
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        let photoLibraryAction = UIAlertAction(title: "Photo Library", style: .Default) { (_) in
            
            imagePicker.sourceType = .PhotoLibrary
            self.presentViewController(imagePicker, animated: true, completion: nil)
        }
        
        actionSheet.addAction(cancelAction)
        actionSheet.addAction(photoLibraryAction)
        self.presentViewController(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func saveButtonTapped(sender: AnyObject) {
        guard let newImage = imageView.image, loggedInUser = loggedInUser, newImageData = UIImagePNGRepresentation(newImage), loggedInUserRecord = loggedInUser.cloudKitRecord  else {
            return
        }
        
        loggedInUser.imageData = newImageData
        
        CloudKitManager.cloudKitController.modifyRecords([loggedInUserRecord], perRecordCompletion: { (record, error) in
            
        }) { (records, error) in
            if let error = error {
                print("Error saving new profile settings. Error: \(error.localizedDescription)")
            } else {
                print("Successfully saved profile changes to CloudKit")
                UserController.sharedController.saveContext()
                
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.dismissViewControllerAnimated(true, completion: nil)
            })
            
        }
    }
    
    @IBAction func cancelButtonTapped(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    @IBAction func deleteAccountButtonTapped(sender: AnyObject) {
        let alert = UIAlertController(title: "Are you sure you want to Delete your Account?", message: "All Contacts and Messages will be deleted.", preferredStyle: .Alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        let deleteAccountAction = UIAlertAction(title: "Yes I'm Sure", style: .Default) { (_) in
            self.deleteAccount()
        }
        alert.addAction(cancelAction)
        alert.addAction(deleteAccountAction)
                dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })

    }
    
    
    func deleteAccount() {
        guard let loggedInUser = loggedInUser, loggedInUserRecord = loggedInUser.cloudKitRecord else {
            return
        }
        
        CloudKitManager.cloudKitController.deleteRecordWithID(loggedInUserRecord.recordID) { (recordID, error) in
            if let error = error {
                print("Error Deleting User Record. Error: \(error.localizedDescription)")
            } else {
                print("Successfully Deleted User Profile")
                UserController.sharedController.fetchContactsFromCoreData({ (contacts) in
                    var contactsToDelete = contacts
                    contactsToDelete.append(loggedInUser)
                    UserController.sharedController.deleteContactsFromCoreData(contactsToDelete)
                    MessageController.sharedController.fetchMessagesFromCoreData({ (messages) in
                        MessageController.sharedController.deleteMessagesFromCoreData(messages)
                        UserController.sharedController.saveContext()
                        self.presentLoginScreen()
                    })
                    
                })
            }
        }
    }
    
    func presentLoginScreen() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyBoard.instantiateViewControllerWithIdentifier("loginScreen")
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(loginVC, animated: true, completion: nil)
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
    
    
    
}
