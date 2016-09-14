//
//  AppDelegate.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 8/28/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

let UpdatedMessages = "UpdatedMessages"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        UINavigationBar.appearance().barTintColor = UIColor ( red: 0.2078, green: 0.7294, blue: 0.7373, alpha: 1.0 )

        let settings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()
        
        self.window?.backgroundColor = .whiteColor()
        
        return true
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        
        guard let remoteDictionary = userInfo as? [String: NSObject] else {
            return
        }
        
        let record = CKQueryNotification(fromRemoteNotificationDictionary: remoteDictionary)
        guard let recordID = record.recordID else {
            print("No recordID from CKQueryNotification")
            return
        }
        
        CloudKitManager.cloudKitController.fetchRecordWithID(recordID) { (record, error) in
            guard let record = record else {
                    print("record was nil")
                    return
            }
            
            MessageController.sharedController.updateOrAddRemoteNotification(record)
        }
            completionHandler(UIBackgroundFetchResult.NewData)
    }
    
    
    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        
        let alert = UIAlertController(title: "New Message", message: notification.alertBody , preferredStyle: .Alert)
        let action = UIAlertAction(title: "Dismiss", style: .Default) { (_) in
            let nc = NSNotificationCenter.defaultCenter()
            nc.postNotificationName(UpdatedMessages, object: nil)
        }
        alert.addAction(action)
        window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
}

