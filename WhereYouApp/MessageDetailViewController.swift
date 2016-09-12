//
//  MessageDetailViewController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/29/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CloudKit

class MessageDetailViewController: UIViewController, CLLocationManagerDelegate, UITextViewDelegate {
    
    var message: Message?
    var loggedInUser: User?
    var usersContact: User?
    var locationManager: CLLocationManager!
    let latSpan: CLLocationDegrees = 0.005
    let longSpan: CLLocationDegrees = 0.005
    let tabBarView = UIView()

    
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var timeDueLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var messageLabel: UILabel!
    
    var location: CLLocation? {
        didSet {
            guard let location = location else {
                print("Location was nil")
                return
            }
            
            let span: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: self.latSpan, longitudeDelta: self.longSpan)
            let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let region = MKCoordinateRegion(center: coordinate, span: span)
            
            mapView.setRegion(region, animated: true)
            
            let myAnnotation = MKPointAnnotation()
            let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay((loggedInUser?.phoneNumber)!)
            myAnnotation.title = loggedInUser?.name ?? formatedPhoneNumber
            
            if let text = messageTextView.text where text != self.defaultMessage {
                myAnnotation.subtitle = text
            } else if let loggedInName = loggedInUser?.name ?? loggedInUser?.phoneNumber {
                myAnnotation.subtitle = "Where \(loggedInName) is"
            }
            myAnnotation.coordinate = coordinate
            mapView.addAnnotation(myAnnotation)
            mapView.showsUserLocation = true
            
        }
    }
    
       let defaultMessage = "type a short message here"
    
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        messageTextView.delegate = self
      //  setupTabBarView()
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        guard let user = UserController.sharedController.loggedInUser,
            message = message else {
                print("message in Detail View is nil OR loggedInUser is nil")
                return
        }
        message.hasBeenSeen = 1
        self.loggedInUser = user
        self.message = message
        // Put the Name of whoever isn't the loggedInUser in the titleLabel
        
        if message.sender.name ?? message.sender.phoneNumber == user.name ?? user.phoneNumber {
            self.usersContact = message.receiver
        } else {
            self.usersContact = message.sender
        }

        updateWith(message)

    }
    
    
    // Updates View with Message Details
    func updateWith(message: Message) {
        
        // Set title to the name of the loggedInUser's contact
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(usersContact!.phoneNumber)

        self.titleLabel.title = usersContact?.name ?? formatedPhoneNumber
        // Sender is looking at message that has not been responded to
        if message.timeResponded == nil && message.sender.phoneNumber == loggedInUser?.phoneNumber {
            updateWithWaitingForReceiverResponse(message)
        }
        // Receiver is looking at message that needs to be filled out and responded to
        else if message.timeResponded == nil && message.receiver.phoneNumber == loggedInUser?.phoneNumber {
            updateWithAToBeFilledRequestMessage(message)
        }
        // Message is filled out and looks the same to reciever and sender
        else {
            updateWithAResponseMessage(message)
        }
    }
    
    
    func updateWithWaitingForReceiverResponse(message: Message) {
        // Update the send button title
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(usersContact!.phoneNumber)

            sendButton.setTitle("Waiting For \(usersContact!.name ?? formatedPhoneNumber) to Check In", forState: .Normal)
    
        self.timeDueLabel.text = "Check In Time: \(dateFormatter.stringFromDate(message.timeDue))"
        // Hide TextView
        messageTextView.hidden = true
        // Disable Send Button
        sendButton.enabled = false
        messageLabel.hidden = true
        
    }
    
    // Updates VC with a message that shows the receiver's response and time the receiver responded
    func updateWithAResponseMessage(message: Message) {
        
        // Update the send button title
        if let timeRespondedDate = message.timeResponded {
            sendButton.setTitle("Checked In \(dateFormatter.stringFromDate(timeRespondedDate))", forState: .Normal)
        }
        self.timeDueLabel.text = "Check In Time: \(dateFormatter.stringFromDate(message.timeDue))"
        
        // Hide TextView
        messageTextView.hidden = true
        // Disable Send Button
        sendButton.enabled = false
        
        // show message label
        messageLabel.hidden = false
        
        if let text = message.text {
            messageLabel.text = text
        } else {
            messageLabel.text = self.defaultMessage
        }
        
        // Get message's location through its latitude and longitude
        guard let latitude = message.latitude,
            let longitude = message.longitude else {
                return
        }
        
        // Create the coordinate through the latitude and longitude
        let latitudeDegrees = CLLocationDegrees(Double(latitude))
        let longitudeDegrees = CLLocationDegrees(Double(longitude))
        let location = CLLocation(latitude: latitudeDegrees, longitude: longitudeDegrees)
        let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let span: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: self.latSpan, longitudeDelta: self.longSpan)
        
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
        
        let myAnnotation = MKPointAnnotation()
        
        myAnnotation.coordinate = coordinate
        
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(usersContact!.phoneNumber)

        myAnnotation.title = self.usersContact?.name ?? formatedPhoneNumber
        // If the Contact decides to send a text message put it in the annotation else give it the defaultMessage
        if let messageText = message.text {
            myAnnotation.subtitle = messageText
        } else {
            myAnnotation.subtitle = defaultMessage
        }
        
        mapView.addAnnotation(myAnnotation)
        
    }
    
    // Updates VC to show the receiver fields to fill out and their current location.
    func updateWithAToBeFilledRequestMessage(message: Message) {
        
        // set the button title back to send and enable it.
        sendButton.setTitle("Send", forState: .Normal)
        sendButton.enabled = true
        
        // Unhide textView
        messageTextView.hidden = false
        applyPlaceholderStyle(messageTextView, placeholderText: self.defaultMessage)

        // hide label
        messageLabel.hidden = true
        
        // Set time due label

        if usersContact?.phoneNumber == usersContact?.name {
            let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(usersContact!.phoneNumber)
             self.timeDueLabel.text = "\(formatedPhoneNumber) wants you to Check In at \(dateFormatter.stringFromDate(message.timeDue))"
        } else {
        self.timeDueLabel.text = "\(usersContact!.name) wants you to Check In at \(dateFormatter.stringFromDate(message.timeDue))"
        }
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkCoreLocationPermission()
        
    }
    
    func checkCoreLocationPermission() {
        if CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse {
            dispatch_async(dispatch_get_main_queue(), {
                self.locationManager.startUpdatingLocation()
                
            })
            
            
        } else if CLLocationManager.authorizationStatus() == .NotDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if CLLocationManager.authorizationStatus() == .Restricted {
            print("Unauthorized to user location service")
            let alert = UIAlertController(title: "Not authorized of use location services", message: nil, preferredStyle: .Alert)
            let action = UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil)
            alert.addAction(action)
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.last {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.location = newLocation
        })

        }
        locationManager.stopUpdatingLocation()
        
    }

    /// Sends Check In Notification to current contact. 
    @IBAction func sendButtonTapped(sender: AnyObject) {
        guard let message = message, loggedInUser = loggedInUser else {
            print("No message to send because it is nil")
            return
        }
        // Get current location
        
        guard let location = location else {
            print("Couldn't get Current Location")
            return
        }
        // Input latitude and longitude into message properties
        let latitude = Double(location.coordinate.latitude)
        let longitude = Double(location.coordinate.longitude)

        message.latitude = latitude
        message.longitude = longitude
        

        // If user doesn't put text in the text view then input a default message.
        if messageTextView.text != defaultMessage {
            message.text = messageTextView.text
        } else {
            if usersContact?.name == usersContact?.phoneNumber {
                let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(loggedInUser.phoneNumber)
                message.text = "\(formatedPhoneNumber) Checked In"
            } else {
                message.text = "\(usersContact?.name!) Checked In"
            }
            
            
        }
        // Input time responded
        message.timeResponded = NSDate()
        
        // Change boolean to show that user has responded to request.
        message.hasResponded = 1

        
               // Get message record and save values to CloudKit
        guard let record = message.cloudKitRecord else {
            // Change Local message properties back to what they were.
            message.latitude = nil
            message.longitude = nil
            message.hasResponded = 0
            message.timeResponded = nil
            message.text = nil
            print("No Message Record NSData or couldn't convert NSData to CKRecord")
            return
        }
        
        guard let text = message.text else {
            return
        }
        
        
        record[Message.textKey] = text
        record[Message.latitudeKey] = latitude
        record[Message.longitudeKey] = longitude
        record[Message.hasRespondedKey] = 1
        record[Message.timeRespondedKey] = NSDate()
        
        CloudKitManager.cloudKitController.modifyRecords([record], perRecordCompletion: { (record, error) in
            
            }) { (records, error) in
                if let error = error {
                    print("Error saving record. Error: \(error.localizedDescription)")
                    // Change Local message properties back to what they were.
                    message.latitude = nil
                    message.longitude = nil
                    message.hasResponded = 0
                    message.timeResponded = nil
                    message.text = nil
                    self.showErrorSendingAlert()
                    return
                } else {
                    print("Saved and sent record")
                    MessageController.sharedController.saveContext()
                }

                
        }
        
        // Change Button Title and Disable
        self.sendButton.setTitle("Message Sent", forState: .Normal)
        self.sendButton.setTitleColor(UIColor ( red: 0.5969, green: 1.0, blue: 0.2341, alpha: 1.0 ), forState: .Normal)
        self.sendButton.enabled = false
        
        // Hide textview and show label
        self.messageTextView.text = ""
        self.messageTextView.hidden = true
        self.messageLabel.text = ""
        self.messageLabel.hidden = false
        
        let formatedPhoneNumber = NumberController.sharedController.formatPhoneForDisplay(loggedInUser.phoneNumber)

        // Put message text in label to show user what they sent.
        if let text = message.text {
            self.messageLabel.text = text
            let annotation = MKPointAnnotation()
            

            annotation.title = loggedInUser.name ?? formatedPhoneNumber
            annotation.subtitle = text
            
            mapView.addAnnotation(annotation)
        } else {
            self.messageLabel.text = "Where\(loggedInUser.name ?? formatedPhoneNumber) Check In"
        }
        
        // Show the time you responded
        self.timeDueLabel.text = "You Checked In \(dateFormatter.stringFromDate(NSDate()))"
        
        
        
        
        // Go back to MessageListTableViewController
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    
    @IBAction func backButtonTapped(sender: AnyObject) {
        navigationController?.popViewControllerAnimated(true)
    }
    
    
    @IBAction func reportButtonTapped(sender: AnyObject) {
        let alert = UIAlertController(title: "Are you sure you want to report this user?", message: nil, preferredStyle: .ActionSheet)
        let noAction = UIAlertAction(title: "No", style: .Cancel, handler: nil)
        let yesAction = UIAlertAction(title: "Yes", style: .Default) { (_) in
            guard let usersContact = self.usersContact else {
                return
            }
            let reportContactRecord = CKRecord(recordType: "ReportedContact")
            reportContactRecord["PhoneNumber"] = usersContact.phoneNumber
            CloudKitManager.cloudKitController.saveRecord(reportContactRecord, completion: { (record, error) in
                if let error = error {
                    print("Error saving record. Error: \(error.localizedDescription)")
                    self.presentTryAgain()
                } else {
                    self.presentSuccess()
                }
            })
            
            
        }
        alert.addAction(noAction)
        alert.addAction(yesAction)
                dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })

    }
    
    func presentTryAgain() {
        let alert = UIAlertController(title: "Something Went wrong. Please Try Again.", message: nil, preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })

    }
    
    func presentSuccess() {
        let alert = UIAlertController(title: "Successfully Reported User!", message: nil, preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(action)
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
        
    }
    
    func showErrorSendingAlert() {
        let alert = UIAlertController(title: "Had trouble Sending Message", message: nil, preferredStyle: .Alert)
        let action = UIAlertAction(title: "Resend Message?", style: .Default) { (_) in

            
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alert.addAction(action)
        alert.addAction(cancelAction)
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentViewController(alert, animated: true, completion: nil)
        })

    }

    
    // MARK: - TextView placeholder
    
    func applyPlaceholderStyle(textView: UITextView, placeholderText: String) {
        
        // make it look (initially) like a placeholder
        textView.textColor = UIColor.lightGrayColor()
        textView.text = placeholderText
        textView.font = UIFont(name: "avenir", size: 14)
    }
    
    func applyNonPlaceholderStyle(textView: UITextView) {
        
        // make it look like normal text instead of a placeholder
        textView.textColor = UIColor.darkTextColor()
        textView.alpha = 1.0
        textView.font = UIFont(name: "avenir", size: 14)
    }
    
    func textViewShouldBeginEditing(textView: UITextView) -> Bool {
        if textView == messageTextView && textView.text == self.defaultMessage {
            // move cursor to start
            moveCursorToStart(textView)
        }
        return true
    }
    
    func moveCursorToStart(textView: UITextView) {
        dispatch_async(dispatch_get_main_queue(), {
            textView.selectedRange = NSMakeRange(0, 0);
        })
    }
    
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        // remove the placeholder text when they start typing
        // first, see if the field is empty
        // if it's not empty, then the text should be black and not italic
        // BUT, we also need to remove the placeholder text if that's the only text
        // if it is empty, then the text should be the placeholder
        let newLength = textView.text.utf16.count + text.utf16.count - range.length
        if newLength > 0 { // have text, so don't show the placeholder
            // check if the only text is the placeholder and remove it if needed
            // unless they've hit the delete button with the placeholder displayed
            if textView == messageTextView && textView.text == self.defaultMessage {
                if text.utf16.count == 0 { // they hit the back button
                    return false // ignore it
                }
                applyNonPlaceholderStyle(textView)
                textView.text = ""
            }
            return true
        } else {  // no text, so show the placeholder
            applyPlaceholderStyle(textView, placeholderText: self.defaultMessage)
            moveCursorToStart(textView)
            return false
        }
    }
    
    func textViewDidChangeSelection (textView: UITextView) {
        // if placeholder is shown, prevent positioning of cursor within or selection of placeholder text
        if textView == messageTextView && textView.text == defaultMessage {
            moveCursorToStart(textView)
        }
    }
    
    func textViewDidEndEditing(textView: UITextView) {
        if messageTextView.text.characters.count == 0 {
            messageTextView.text = self.defaultMessage
            messageTextView.textColor = .lightGrayColor()
        }
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
