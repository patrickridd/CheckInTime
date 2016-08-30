//
//  MessageListTableViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit

class MessageListTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let user = UserController.sharedController.user else {
            presentLoginScreen({ (user) in
                
            })
            return
        }
        
        
        
    
        
    }
    
    
    func presentLoginScreen(completion: (user: User)->Void) {
        var phoneTextField: UITextField?
        var nameTextField: UITextField?
        
        let loginScreen = UIAlertController(title: "Create Your Account", message: nil, preferredStyle: .ActionSheet)
        loginScreen.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "enter your name"
            nameTextField = textField
        }
        loginScreen.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "enter your phone number"
            phoneTextField = textField
        }
        let submitButton = UIAlertAction(title: "Submit", style: .Default) { (_) in
            guard let name = nameTextField?.text,
                phoneNumber = phoneTextField?.text else {
                    return
            }
            
            UserController.sharedController.createUser(name, phoneNumber: phoneNumber)
            completion(user: <#T##User#>)
        }
        
        loginScreen.addAction(submitButton)
        
        self.presentViewController(loginScreen, animated: true, completion: nil)
        
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
   
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("messageCell", forIndexPath: indexPath)
        return cell
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
