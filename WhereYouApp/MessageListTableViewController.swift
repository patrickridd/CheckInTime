//
//  MessageListTableViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
//import CloudKit

class MessageListTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        CloudKitManager.cloudKitController.checkIfUserIsLoggedIn { (signedIn) in
            if !signedIn {
                self.presentICloudAlert()
                return
            }
        }
        UserController.sharedController.checkForUserAccount { (hasAccount) in
            if !hasAccount {
                self.presentLoginScreen()
                return
            }
        }
        
        
        
        
    }

    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
                
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
            self.presentViewController(alert, animated: true, completion: nil)
    
        
        
    }
    
    func presentLoginScreen() {
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyBoard.instantiateViewControllerWithIdentifier("loginScreen")
        self.presentViewController(loginVC, animated: true, completion: nil)
        
    }
    

    
    
        
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return MessageController.sharedController.fetchedResultsController.sections?.count ?? 0
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = MessageController.sharedController.fetchedResultsController.sections else {
            return 0
        }
        
        return sections[section].numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithIdentifier("messageCell", forIndexPath: indexPath) as? MessageTableViewCell, message = MessageController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as? Message  else {
            return UITableViewCell()
        }
        
        cell.updateWith(message)
        
        
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
