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
    
    
    static let sharedController = MessageListTableViewController()
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        UserController.sharedController.checkForCoreDataUserAccount({ (hasAccount) in
            if !hasAccount {
                self.presentLoginScreen()
                return
            }
            
        })
        
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
