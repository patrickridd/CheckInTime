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
            myAnnotation.title = loggedInUser?.name
            myAnnotation.subtitle = messageTextView.text ?? defaultMessage
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
    
    
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        guard let user = UserController.sharedController.loggedInUser,
            message = message else {
                print("message in Detail View is nil OR loggedInUser is nil")
                return
        }
        self.loggedInUser = user
        
        // Put the Name of whoever isn't the loggedInUser in the titleLabel
        
        if message.sender.name == user.name {
            self.usersContact = message.receiver
        } else {
            self.usersContact = message.sender
        }

        updateWith(message)

    }
    
    
    // Updates View with Message Details
    func updateWith(message: Message) {
        
        // Set title to the name of the loggedInUser's contact
        self.titleLabel.title = usersContact?.name
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
    
//    func setupTabBarView() {
//        tabBarView.leftAnchor.isEqual(self.view?.leftAnchor)
//        tabBarView.rightAnchor.isEqual(self.view?.rightAnchor)
//        tabBarView.bottomAnchor.isEqual(self.view?.bottomAnchor)
//        tabBarView.topAnchor.isEqual(self.messageTextView?.bottomAnchor)
//        //let tabBarHeightContstraint = NSLayoutConstraint(item: tabBarView, attribute: .Height, relatedBy: .Equal, toItem: self.view, attribute: .Height, multiplier: 1/8, constant: 0)
//      //  tabBarView.addConstraint(tabBarHeightContstraint)
//        tabBarView.backgroundColor = UIColor.redColor()
//
//        view.addSubview(tabBarView)
//    }
    
    
    func updateWithWaitingForReceiverResponse(message: Message) {
        // Update the send button title
            sendButton.setTitle("Waiting For \(usersContact!.name) to Respond", forState: .Normal)
    
        self.timeDueLabel.text = "Time Due: \(dateFormatter.stringFromDate(message.timeDue))"
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
            sendButton.setTitle("Responded at \(dateFormatter.stringFromDate(timeRespondedDate))", forState: .Normal)
        }
        self.timeDueLabel.text = "Time Due: \(dateFormatter.stringFromDate(message.timeDue))"
        
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
        
        myAnnotation.title = self.usersContact?.name
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
        self.timeDueLabel.text = "\(usersContact!.name) requests to know WhereYouApp by \(dateFormatter.stringFromDate(message.timeDue))"
        
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
    
    

    
    @IBAction func sendButtonTapped(sender: AnyObject) {
        
    }
    
    @IBAction func backButtonTapped(sender: AnyObject) {
        navigationController?.popToRootViewControllerAnimated(true)
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
