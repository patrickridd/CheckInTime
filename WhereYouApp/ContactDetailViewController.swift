//
//  ContactDetailViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CoreData

class ContactDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {

    
    var contact: User?
    var fetchedResultsController: NSFetchedResultsController!
    let moc = Stack.sharedStack.managedObjectContext
    
    
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    @IBOutlet weak var contactImage: UIImageView!
    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet var dueDatePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let contact = contact else {
            return
        }
        setupFetchController(contact)
        
        dateTextField.inputView = dueDatePicker
        updateWith(contact)

    }
    
    
    

    func updateWith(contact: User) {
        self.contactImage.image = contact.photo
        self.nameLabel.text = contact.name
        self.numberLabel.text = contact.phoneNumber
        
        
    }
    
    
    func setupFetchController(contact: User) {
        
        let request = NSFetchRequest(entityName: "Message")
        let descriptor = NSSortDescriptor(key: "timeSent", ascending: true)
        request.sortDescriptors = [descriptor]
        let receiverPredicate = NSPredicate(format: "receiver == %@", argumentArray: [contact])
        let senderPredicate = NSPredicate(format: "sender == %@", argumentArray: [contact])
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [receiverPredicate,senderPredicate])
        request.predicate = compoundPredicate
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: "receiver", cacheName: nil  )
        
        let _ = try? fetchedResultsController.performFetch()
        
        
    }
    
    @IBAction func whereYouAppButtonTapped(sender: AnyObject) {
    }

    @IBAction func screenTapped(sender: AnyObject) {
        dateTextField.resignFirstResponder()
        dateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)
    }
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        guard let sections = fetchedResultsController.sections else {
            return 1
        }
        return sections.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = fetchedResultsController.sections else {
            return 1
        }
        return sections[section].numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithIdentifier("messageCell", forIndexPath: indexPath) as? MessageTableViewCell, let message = fetchedResultsController.objectAtIndexPath(indexPath) as? Message else {
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
