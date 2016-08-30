//
//  LoginViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/30/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var numberTextField: UITextField!
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func submitButtonTapped(sender: AnyObject) {
        guard let image = imageView.image, let name = nameTextField.text where name.characters.count > 0 else {
            self.presentNameAlert()
            return
        }
            guard let phoneNumber = numberTextField.text where phoneNumber.characters.count >= 10 else {
                self.presentNumberAlert()
                return
        }
        
        UserController.sharedController.createUser(name, phoneNumber: phoneNumber, image: image)
    }
    
    @IBAction func changePhotoButtonTapped(sender: AnyObject) {
        let alert = UIAlertController(title: "Choose Image Source", message: nil, preferredStyle: .ActionSheet)
        
        let photoLibraryAction = UIAlertAction(title: "Photo Library", style: .Default) { (_) in
            self.imagePicker.sourceType = .PhotoLibrary
            self.presentViewController(self.imagePicker, animated: true, completion: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alert.addAction(photoLibraryAction)
        alert.addAction(cancelAction)
        
        self.presentViewController(alert, animated: true, completion: nil)

        
        
    }
    
    func presentNameAlert() {
        let alert = UIAlertController(title: nil, message: "Name needs one character or more", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        
    }
    
    func presentNumberAlert() {
        let alert = UIAlertController(title: nil, message: "Phone Number needs 10 digits or more", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        

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
