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
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet weak var sendButton: UIBarButtonItem!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var messageLabel: UILabel!

    var locationManager: CLLocationManager!
    let latSpan: CLLocationDegrees = 0.005
    let longSpan: CLLocationDegrees = 0.005
    let defaultMessage = "This is WhereIMApp"
    
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let loggedInUser = UserController.sharedController.loggedInUser, message = message else {
            print("message in Detail View is nil OR loggedInUser is nil")
            return
        }
        self.loggedInUser = loggedInUser
        
        // Put the Name of whoever isn't the loggedInUser in the titleLabel

        if message.sender.name == loggedInUser.name {
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
        
        // Hide TextView
        textView.hidden = true
        // Disable Send Button
        sendButton.enabled = false
        
        if let text = message.text {
            messageLabel.text = text
        } else {
            messageLabel.text = defaultMessage
        }
        
        guard let latitude = message.latitude,
            let longitude = message.longitude else {
                return
        }
        
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
        if let messageText = message.text {
            myAnnotation.subtitle = messageText
        } else {
            myAnnotation.subtitle = defaultMessage
        }
       // TODO
        
    }
    
    func updateWithAToBeFilledRequestMessage(message: Message) {
        
    }
    
    @IBAction func sendButtonTapped(sender: AnyObject) {
    
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
