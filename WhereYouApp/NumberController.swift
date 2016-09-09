//
//  NumberController.swift
//  WhereYouApp
//
//  Created by Patrick Ridd on 9/8/16.
//  Copyright © 2016 PatrickRidd. All rights reserved.
//

import Foundation
import ContactsUI

class NumberController {
    
    
    static let sharedController = NumberController()
    
    /// Gets Mobile phone number and fomats it so we can use it as a predicate when searching for User in CloudKit
    func getiPhoneNumberFormatedForUserRecordName(numbers: [CNLabeledValue]) -> [String] {
        
        var phoneNumbers = [String]()
        
        // Find The Mobile Phone Number in Contacts and remove any punctuation and white spacing
        for phoneNumberLabel in numbers {
            if phoneNumberLabel.label != CNLabelPhoneNumberiPhone {
                break
            }
            let phoneNumber = phoneNumberLabel.value as! CNPhoneNumber
            let stringPhoneNumber = phoneNumber.stringValue
            let phoneWhite = stringPhoneNumber.lowercaseString.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).joinWithSeparator(" ")
            let noPunc =  phoneWhite.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuationCharacterSet()).joinWithSeparator("")
            let noSpaces = noPunc.stringByReplacingOccurrencesOfString(" ", withString: "")
            
            phoneNumbers.append(noSpaces)
        }
        return phoneNumbers
    }

    /// Formats Phone Correctly
    func checkIfPhoneHasTheRightAmountOfDigits(inout phoneNumber: String, completion: (isFormattedCorrectly: Bool, formatedNumber: String) -> Void) {
        
        // If number has a 1 before the area code and phone number remove it.
        if phoneNumber.characters.count > 10 {
            phoneNumber.removeAtIndex(phoneNumber.startIndex)
        } else {
            // Else the number is fine
            completion(isFormattedCorrectly: true, formatedNumber: phoneNumber)
        }
        
        // If still not a 10 number digit then we don't accept it.
        if phoneNumber.characters.count != 10 {
            completion(isFormattedCorrectly: false, formatedNumber: phoneNumber)
        } else {
            // If we formatted correctly then return true and the formated number
            completion(isFormattedCorrectly: true, formatedNumber: phoneNumber)
        }
        
        
        
    }
    
    
    
}