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
        guard let loggedInUser = UserController.sharedController.loggedInUser else {
            return
        }
        self.loggedInUser = loggedInUser
        imageView.image = loggedInUser.photo
        view.layoutIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupImage()
        
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
        dispatch_async(dispatch_get_main_queue(), {
            actionSheet.popoverPresentationController?.sourceView = self.view
            actionSheet.popoverPresentationController?.sourceRect = self.view.bounds
            // this is the center of the screen currently but it can be any point in the view
            self.presentViewController(actionSheet, animated: true, completion: nil)
            
        })
        
    }
    
    @IBAction func saveButtonTappedWithSender(sender: AnyObject) {
        loadingAlert("Updating Profile...")
        
        guard let newImage = imageView.image,
            let loggedInUser = loggedInUser,
            let newImageData = UIImagePNGRepresentation(newImage),
            let loggedInUserRecord = loggedInUser.cloudKitRecord  else {
                self.dismissViewControllerAnimated(true, completion: nil)
                return
        }
        loggedInUser.imageData = newImageData
        loggedInUserRecord[User.imageKey] = loggedInUser.imageAsset
        CloudKitManager.cloudKitController.modifyRecords([loggedInUserRecord], perRecordCompletion: { (record, error) in
            
        }) { (records, error) in
            if let error = error {
                print("Error saving new profile settings. Error: \(error.localizedDescription)")
            } else {
                print("Successfully saved profile changes to CloudKit")
                UserController.sharedController.saveContext()
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.dismissViewControllerAnimated(true, completion: { 
                    
                    self.dismissViewControllerAnimated(true, completion: nil)
                })
            })
        }
    }
    
    @IBAction func cancelButtonTappedWithSender(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    @IBAction func deleteAccountButtonTapped(sender: AnyObject) {
        let alert = UIAlertController(title: "Are you sure you want to Delete your Account?", message: "All Contacts and Messages will be deleted.", preferredStyle: .Alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        let deleteAccountAction = UIAlertAction(title: "Yes I'm Sure", style: .Default) { (_) in
            self.loadingAlert("Deleting Account...")
            UserController.sharedController.deleteAccount({
                dispatch_async(dispatch_get_main_queue(), {
                    self.dismissViewControllerAnimated(true, completion: {
                        self.presentLoginScreen()
                    })
                })  
            })
        }
        alert.addAction(cancelAction)
        alert.addAction(deleteAccountAction)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
        
    }
    
    
    /// Presents a loading alert to let the user know that it is updatint the profile.
    func loadingAlert(alert: String) {
        let alert = UIAlertController(title: nil, message: alert, preferredStyle: .Alert)
        
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
    
    
    func presentLoginScreen() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyBoard.instantiateViewControllerWithIdentifier("loginScreen")
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(loginVC, animated: true, completion: nil)
        })
    }
    
    func setupImage() {
        let radius = imageView.frame.width/2.0
        self.imageView.layer.masksToBounds = true
        self.imageView.layer.cornerRadius = radius
        self.imageView.clipsToBounds = true
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
    
    
    
}
