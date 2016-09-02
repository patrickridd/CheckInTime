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

class MessageDetailViewController: UIViewController, CLLocationManagerDelegate {

    var message: Message?
    var loggedInUser: User?
    var usersContact: User?
    
    @IBOutlet weak var timeDueLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet weak var sendButton: UIBarButtonItem!
    @IBOutlet weak var textView: UITextView!
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
            myAnnotation.subtitle = textView.text ?? defaultMessage
            myAnnotation.coordinate = coordinate
            mapView.addAnnotation(myAnnotation)
            mapView.showsUserLocation = true
            
        }
    }

    var locationManager: CLLocationManager!
    let latSpan: CLLocationDegrees = 0.005
    let longSpan: CLLocationDegrees = 0.005
    let defaultMessage = "This is WhereImApp"
    
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    

    
    override func viewDidLoad() {
        super.viewDidLoad()

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
        
        
        // Check to see if this is a request message or a response to a message
        if message.timeResponded != nil {
            updateWithAResponseMessage(message)
        } else {
            updateWithAToBeFilledRequestMessage(message)
        }
        
    }
    
    func updateWithAResponseMessage(message: Message) {
        
        // Update the send button title
        if let timeRespondedDate = message.timeResponded {
        sendButton.title = "Responded at \(dateFormatter.stringFromDate(timeRespondedDate))"
        }
        self.timeDueLabel.text = "Time Due: \(dateFormatter.stringFromDate(message.timeDue))"
        
        // Hide TextView
        textView.hidden = true
        // Disable Send Button
        sendButton.enabled = false
        
        // show message label
        messageLabel.hidden = false
        
        if let text = message.text {
            messageLabel.text = text
        } else {
            messageLabel.text = defaultMessage
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
    
    func updateWithAToBeFilledRequestMessage(message: Message) {
    
        // set the button title back to send and enable it.
        sendButton.title = "Send"
        sendButton.enabled = true
        
        // Unhide textView
        textView.hidden = false
        // hide label
        messageLabel.hidden = true
        
        // Set time due label
        self.timeDueLabel.text = dateFormatter.stringFromDate(message.timeDue)
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
      //  checkCoreLocationPermission()
        
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
            self.location = newLocation
        }
        locationManager.stopUpdatingLocation()
        
    }
    
    @IBAction func sendButtonTapped(sender: AnyObject) {
    
    }
  
    @IBAction func backButtonTapped(sender: AnyObject) {
        navigationController?.popToRootViewControllerAnimated(true)
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
