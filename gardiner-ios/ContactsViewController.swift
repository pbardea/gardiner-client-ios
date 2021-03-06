//
//  ContactsViewController.swift
//  gardiner-ios
//
//  Created by Bilal Akhtar on 2014-10-19.
//  Copyright (c) 2014 Bilal Akhtar. All rights reserved.
//

import UIKit
import AddressBook

class ContactsViewController: UITableViewController {
    
    var requests:[Contact] = []
    var otherContacts:[Contact] = []
    var contacts:[Contact] = []
    
    /*class ContactsSearchDelegate: NSObject, UITableViewDataSource, UISearchDisplayDelegate, UITableViewDelegate {
        var searchContacts:[Contact] = []
        
        func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            var cell:UITableViewCell = tableView.dequeueReusableCellWithIdentifier("contactsSearchCell") as! UITableViewCell
            var contact = searchContacts[indexPath.row]
            cell.textLabel?.text = contact.name
            
            return cell
        }
        
        func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return searchContacts.count
        }
        
        /*func searchDisplayController(controller: UISearchDisplayController, didLoadSearchResultsTableView tableView: UITableView) {
            tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "contactsSearchCell")
        }
        
        func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String!) -> Bool {
            RestApi.instance.request(.GET, endpoint: "contacts/search", callback: { (request, response, json) -> Void in
                self.searchContacts = Contact.parseList(json)
                controller.searchResultsTableView.reloadData()
                
            }, parameters: ["name":searchString])
            
            return false
        }*/
        
        func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
            println("Selected \(searchContacts[indexPath.row].name) in search results")
            
            let contact:Contact = searchContacts[indexPath.row]
            
            var alert:UIAlertController = UIAlertController(title: "Add this contact?", message: "Send request", preferredStyle: UIAlertControllerStyle.ActionSheet)
            
            var addAction:UIAlertAction = UIAlertAction(title: "Send request", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
                
                RestApi.instance.request(.POST, endpoint: "contacts/user/\(contact.id)/request", callback: { (request, response, json) -> Void in
                    tableView.deselectRowAtIndexPath(indexPath, animated: true)
                })
            }
            alert.addAction(addAction)
            
            //self.presentViewController(alert, animated: true, completion: nil)
        }
    }*/
    
    func checkContacts(addressBook: ABAddressBook) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let contacts = ABAddressBookCopyArrayOfAllPeople(addressBook).takeRetainedValue() as NSArray as [ABRecord]
            var phoneNumbers:[String] = []
            
            for contact in contacts {
                
                if ABRecordGetRecordType(contact) == UInt32(kABPersonType)  {
                    let phoneNumberProperty:ABMultiValueRef = ABRecordCopyValue(contact, kABPersonPhoneProperty).takeRetainedValue() as ABMultiValueRef
                    
                    let phoneNumberValues:[String] = ABMultiValueCopyArrayOfAllValues(phoneNumberProperty).takeUnretainedValue() as NSArray as! [String]
                    
                    for phoneNumber in phoneNumberValues {
                        //println(phoneNumber)
                        phoneNumbers.append(phoneNumber)
                    }
                }
            }
            
            if phoneNumbers.count == 0 {
                return
            }
            
            RestApi.instance.request(.POST, endpoint: "contacts/search", parameters: ["phoneNumbers": phoneNumbers]) { (request, response, json) -> Void in
                self.otherContacts = Contact.parseList(json)
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
                
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        refresh()

        var error:Unmanaged<CFError>? = nil
        var addressBook:ABAddressBook = ABAddressBookCreateWithOptions(nil, &error).takeRetainedValue()
        var authStatus = ABAddressBookGetAuthorizationStatus()
        if authStatus == ABAuthorizationStatus.NotDetermined {
            
            ABAddressBookRequestAccessWithCompletion(addressBook, { (granted, error) -> Void in
                if granted == true {
                    self.checkContacts(addressBook)
                }
            })
        } else if authStatus == ABAuthorizationStatus.Authorized {
            checkContacts(addressBook)
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:UITableViewCell = tableView.dequeueReusableCellWithIdentifier("requestsListCell") as! UITableViewCell
        var contact:Contact?
        if indexPath.section == 0 {
            contact = self.requests[indexPath.row]
        } else {
            contact = self.otherContacts[indexPath.row]
        }
        
        cell.textLabel?.text = contact!.name
        
        return cell
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
        
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // Requests
            return requests.count
        } else if section == 1 {
            // Other contacts
            return otherContacts.count
        }
        
        return 1
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Requests"
        case 1:
            return "Other contacts on Gardiner"
        default:
            return "Unknown"
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch indexPath.section {
        case 0:
            let contact:Contact = self.requests[indexPath.row]
            self.requests.removeAtIndex(indexPath.row)
            tableView.reloadData()
            
            RestApi.instance.request(.POST, endpoint: "contacts/requests/\(contact.requestId)/respond", parameters: ["response":"1"])
        case 1:
            let contact:Contact = self.otherContacts[indexPath.row]
            var confirmer:UIAlertController = UIAlertController(title: "Request", message: "Are you sure you want to send a contact request to \(contact.name)?", preferredStyle: UIAlertControllerStyle.Alert)
            confirmer.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
                contact.request()
                confirmer.dismissViewControllerAnimated(true, completion: nil)
            }))
            confirmer.addAction(UIAlertAction(title: "No", style: .Cancel, handler: { (action) -> Void in
                confirmer.dismissViewControllerAnimated(true, completion: nil)
            }))
            self.presentViewController(confirmer, animated: true, completion: nil)
        default:
            break
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    func refresh() {
        RestApi.instance.request(.GET, endpoint: "contacts/requests", callback: { (request, response, json) -> Void in
            for request in json["requests"] as! NSArray {
                var contact:Contact = Contact.parseJson(request["from"] as! NSDictionary)
                contact.requestId = request["id"] as! String
                
                self.requests.append(contact)
            }
            
            self.tableView.reloadData()
        })
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
