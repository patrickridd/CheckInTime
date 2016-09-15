//
//  SentMessagesTableViewController.swift
//  CheckInTime
//
//  Created by Patrick Ridd on 9/15/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CoreData

class SentMessagesTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate  {
    
    let rightProfileButtonImage = UIButton()
    
    static let sharedController = MessageListTableViewController()
    @IBOutlet weak var tableView: UITableView!
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        MessageController.sharedController.fetchedResultsController.delegate = self
        UserController.sharedController.checkForCoreDataUserAccount({ (hasAccount, hasConnection) in
            if !hasAccount {
                self.presentLoginScreen()
                return
            }
            if !hasConnection {
                self.presentCouldNotGetCKAccount()
            }
        })
        setupTabBar()
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(updatedMessage), name: UpdatedMessages, object: nil)
        
        setupNavBar()
        setupRightButton()
        
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        guard let user = UserController.sharedController.loggedInUser else {
            return
        }
        rightProfileButtonImage.setImage(user.photo, forState: .Normal)
        
        
    }
    
    func updatedMessage(notification: NSNotification) {
        self.tableView.reloadData()
    }
    
    func presentCouldNotGetCKAccount() {
        let alert = UIAlertController(title: "We couldn't find your Check In Account on Our Server", message: "This could be a problem with your connection and you may want to restart the application. Do you want us to try to find your account again, or do you want to create a new one?", preferredStyle: .Alert)
        let createNewOneAction = UIAlertAction(title: "Create New Account", style: .Default) { (_) in
            let areYouSureAlert = UIAlertController(title: "Are You Sure You Want to Delete Local Account and Create a New One?", message: nil, preferredStyle: .Alert)
            let noAction = UIAlertAction(title: "No", style: .Cancel, handler: { (_) in
                self.presentGeneralError()
            })
            let yesAction = UIAlertAction(title: "Yes", style: .Default, handler: { (_) in
                
                UserController.sharedController.deleteAccount({
                    dispatch_async(dispatch_get_main_queue(), {
                        self.presentLoginScreen()
                    })
                })
            })
            areYouSureAlert.addAction(noAction)
            areYouSureAlert.addAction(yesAction)
            dispatch_async(dispatch_get_main_queue(), {
                self.presentViewController(areYouSureAlert, animated: true, completion: nil)
            })
            
        }
        let tryToFindAgain = UIAlertAction(title: "Try Again", style: .Default) { (_) in
            guard let user = UserController.sharedController.loggedInUser else {
                self.presentGeneralError()
                return
            }
            UserController.sharedController.fetchUsersCloudKitRecord(user, completion: { (record) in
                if let _ = record {
                    self.presentSuccessfullyFoundAccount()
                } else {
                    self.presentCouldNotGetCKAccount()
                }
            })
        }
        alert.addAction(createNewOneAction)
        alert.addAction(tryToFindAgain)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    
    func presentGeneralError() {
        let alert = UIAlertController(title: "We're sorry, but something went wrong", message: "Please Restart Curfew Check", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
        
    }
    
    func presentSuccessfullyFoundAccount() {
        let alert = UIAlertController(title: "Successfully found your Account", message: "Please Restart Curfew Check", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(action)
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
    
    
    func setupTabBar() {
        let tabBar = tabBarController?.tabBar
        UITabBarItem.appearance().setTitleTextAttributes([NSForegroundColorAttributeName: UIColor ( red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0 )], forState:.Normal)
        tabBar?.tintColor = UIColor ( red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0 )
        tabBar?.barTintColor = UIColor ( red: 0.2078, green: 0.7294, blue: 0.7373, alpha: 1.0 )
        
    }
    
    func setupNavBar() {
        let image = UIImage(named: "CheckInTimeTitleWhiteSmall")
        let imageView = UIImageView(image: image)
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .Plain, target: nil, action: nil)
        UINavigationBar.appearance().tintColor = UIColor.whiteColor()
        
        self.navigationItem.titleView = imageView
    }
    
    func setupRightButton() {
        guard let user = UserController.sharedController.loggedInUser else {
            return
        }
        
        rightProfileButtonImage.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        rightProfileButtonImage.layer.cornerRadius = 20
        rightProfileButtonImage.layer.masksToBounds = true
        rightProfileButtonImage.setBackgroundImage(user.photo, forState: .Normal)
        
        let minSideSize = min(rightProfileButtonImage.frame.size.width, rightProfileButtonImage.frame.size.height)
        let radius = minSideSize / 2
        
        rightProfileButtonImage.clipsToBounds = true
        rightProfileButtonImage.layer.cornerRadius = radius
        rightProfileButtonImage.contentMode = .ScaleAspectFit
        self.navigationItem.rightBarButtonItem?.customView = rightProfileButtonImage
        rightProfileButtonImage.addTarget(self, action: #selector(presentProfilePage), forControlEvents: UIControlEvents.TouchUpInside)
    }
    
    func presentProfilePage() {
        let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
        let profilePage = storyBoard.instantiateViewControllerWithIdentifier("profilePage")
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(profilePage, animated: true, completion: nil)
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
            MessageController.sharedController.deleteMessagesFromCoreData([message])
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
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "messageSegue" {
            // Get the new view controller using segue.destinationViewController.
            guard let messageDetailVC = segue.destinationViewController as? MessageDetailViewController,
                let indexPath = tableView.indexPathForSelectedRow else {
                    return
            }
            let message = MessageController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as? Message
            messageDetailVC.message = message
            
            // Pass the selected object to the new view controller.
            
        } else if segue.identifier == "profileSegue" {
            guard let profileVC = segue.destinationViewController as? ProfileViewController,
                let user = UserController.sharedController.loggedInUser else {
                    return
            }
            
            profileVC.loggedInUser = user
            
        }
    }
    
}

