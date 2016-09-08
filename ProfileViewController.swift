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
    @IBOutlet weak var usernameTextField: UITextField!
    
    
    
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
        
        if let newName = usernameTextField.text where newName.characters.count > 0{
            loggedInUser.name = newName
        }
        
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
        guard let loggedInUser = loggedInUser, loggedInUserRecord = loggedInUser.cloudKitRecord else {
            return
        }
        
        CloudKitManager.cloudKitController.deleteRecordWithID(loggedInUserRecord.recordID) { (recordID, error) in
            if let error = error {
                print("Error Deleting User Record. Error: \(error.localizedDescription)")
            } else {
                print("Successfully Deleted User Profile")
                UserController.sharedController.moc.deleteObject(loggedInUser)
            }
            
            
        }
        
    }
    
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            print("Couldn't Get Image from imagePicker 'info'")
            return
        }
        
        imageView.image = image
        dismissViewControllerAnimated(true, completion: nil)
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
