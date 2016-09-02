//
//  MessageListTableViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CoreData

class MessageListTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate  {
    
    
    static let sharedController = MessageListTableViewController()
    @IBOutlet weak var tableView: UITableView!
   
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false

        MessageController.sharedController.fetchedResultsController.delegate = self
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
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentViewController(loginVC, animated: true, completion: nil)
        })

        
    }
    
    
    
    // Data Source Methods
    
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
    
    // Override to support editing the table view.
     func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            guard let message = MessageController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as? Message else {
                return
            }
            MessageController.sharedController.deleteMessage(message)
            
            //tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }
    
     func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections = MessageController.sharedController.fetchedResultsController.sections else { return nil }
        
        
        guard let phoneNumber = UserController.sharedController.loggedInUser?.phoneNumber else { return "WhereYouApp" }
        print(sections[section].name)
        if sections[section].name == phoneNumber {
            return "WhereYouApp Requests"
        } else {
            return "People want to Know WhereYouApp"
        }
        
        
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
        case .Insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
        default: break
        }
        
    }
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        
        switch type {
        case .Delete:
            guard let indexPath = indexPath else { return }
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        case .Insert:
            guard let newIndexPath = newIndexPath else { return }
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
        case .Update:
            guard let indexPath = indexPath else { return }
            
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        case .Move:
            guard let indexPath = indexPath, newIndexPath = newIndexPath else { return }
            
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
        }
        
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
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
