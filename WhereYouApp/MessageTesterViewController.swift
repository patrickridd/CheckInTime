//
//  MessageTesterViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/31/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit

class MessageTesterViewController: UIViewController {

    @IBOutlet var dueDatePicker: UIDatePicker!
    @IBOutlet weak var dueDateTextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        dueDateTextField.inputView = dueDatePicker
        guard let text = dueDateTextField.text else {
            print("nothing in textfield")
            return
        }
        print(text)
    }
        let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    @IBAction func cancelButtonTapped(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
        
    }

    @IBAction func sendButtonTapped(sender: AnyObject) {
        dueDateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)

        
    }
    
    @IBAction func screenTapped(sender: AnyObject) {
        dueDateTextField.resignFirstResponder()
        dueDateTextField.text = dateFormatter.stringFromDate(dueDatePicker.date)

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
