//
//  AccountController.swift
//  CanvasCore
//
//  Created by Sam Soffes on 11/3/15.
//  Copyright © 2015–2016 Canvas Labs, Inc. All rights reserved.
//

import CanvasKit
// import SAMKeychain
import CloudKit

open class AccountController {

	// MARK: - Properties

	open var currentAccount: Account? {
		didSet {
			if let account = currentAccount, let _ = try? JSONSerialization.data(withJSONObject: account.dictionary, options: []) {
				// SAMKeychain.setPasswordData(data, forService: "Canvas", account: "Account")
			} else {
				// SAMKeychain.deletePasswordForService("Canvas", account: "Account")
				UserDefaults.standard.removeObject(forKey: "Projects")
				UserDefaults.standard.removeObject(forKey: "SelectedProject")
			}
 
            let userDefaults = UserDefaults.standard
            if let account = currentAccount {
                userDefaults.set(account.user.username, forKey: AccountController.UsernameField)
                userDefaults.set(account.recordName, forKey: AccountController.ICloudRecordName)
            } else {
                userDefaults.removeObject(forKey: AccountController.UsernameField)
                userDefaults.removeObject(forKey: AccountController.ICloudRecordName)
            }

            // Make sure we do this on the main thread, since this call seems to propagate the
            // event on the same thread as it is posted on.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: type(of: self).accountDidChangeNotificationName), object: nil)
            }
		}
	}

	open static let accountDidChangeNotificationName = "AccountController.accountDidChangeNotification"

	open static let sharedController = AccountController()

    private var group: DispatchGroup
    private var recordID: CKRecordID?
    

	// MARK: - Initializers

	init() {
        
        group = DispatchGroup()
        
        NotificationCenter.default.addObserver(self, selector: #selector(identityDidChange), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
        
        updateAccountStatus()
        
        return
	}
    
    public func createAccount(username: String, completion: @escaping (String?) -> Void) {
        
        guard let recordID = recordID else { return }
        
        let record = CKRecord(recordType: AccountController.TribalUsers)
        record[AccountController.ICloudRecordName] = recordID.recordName as CKRecordValue
        record[AccountController.UsernameField] = username as CKRecordValue
        record[AccountController.RegistrationDateField] = NSDate() as CKRecordValue
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        
        database.save(record) { (record, error) -> Void in
            
            if let error = error {
                completion("Unexpected error: \(error.localizedDescription)")
                return
            }
            
            guard let record = record else {
                fatalError("Save did not return record on success")
            }
            
            // The save() call might need to complete before we can count on queries have the
            // results of its action, so we async the following
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2000)) {
                // The delay above is a kludge.  But it allows the work to proceed and it is not
                // in the critical, daily-use path so an additional 2 seconds may just be good enough.
                // Need to make sure that the username is unique.  Since it does not appear to be possible
                // to force a constraint, we will just see if we created the first entry with that username
                // or if we are later.  If later, then we will delete the record and tell the user
                
                let predicate = NSPredicate(format:"%K == %@", AccountController.UsernameField, username)
                let query = CKQuery(recordType: AccountController.TribalUsers, predicate: predicate)
                query.sortDescriptors = [NSSortDescriptor(key: AccountController.RegistrationDateField, ascending: true)]
                database.perform(query, inZoneWith: nil) { (results, error) -> Void in

                    if let error = error {
                        completion("Unexpected error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let results = results, let first = results.first else {
                        // This should never happen, but sometimes the timing at the database causes this to fail.
                        // So, we delete the created entry and ask the user to try again.  Not very nice
                        // but the best we have until I determine a better way to confirm a unique entry
                        database.delete(withRecordID: record.recordID) { (recordID, error) -> Void in
                            completion("Unexpected error:  please try again")
                        }
                        return
                    }
                    
                    let firstCreated = first[AccountController.ICloudRecordName] as? String
                    if firstCreated != recordID.recordName {
                        
                        database.delete(withRecordID: record.recordID) { (recordID, error) -> Void in
                            completion("Username not available")
                        }
                    } else {
                        // Only one account present, so we are good
                        let account = Account(recordName: recordID.recordName, username: username)
                        DispatchQueue.main.async {
                            self.currentAccount = account
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
    
    // We need to cache the account information locally in case we are not able to get online.
    // We also need to confirm that the cached information is correct, so we will check it when
    // we are able to access the cloud servers.
    
    private func updateAccountStatus() {
        
        let username = UserDefaults.standard.string(forKey: AccountController.UsernameField)
        let recordName = UserDefaults.standard.string(forKey: AccountController.ICloudRecordName)
        
        // If we know the current account information, create an account and set it
        if let username = username, let recordName = recordName {
            let account = Account(recordName: recordName, username: username)
            self.currentAccount = account
        }
        
        let container = CKContainer.default()
        group.enter()
        container.fetchUserRecordID { (recordID, error) -> Void in
            if error == nil, let recordID = recordID {
                self.recordID = recordID
                self.fetchTribalUsername(container.publicCloudDatabase, recordID: recordID) { (Void) -> Void in
                    self.group.leave()
                }
            } else {
                self.group.leave()
            }
        }
    }
    
    public static let TribalUsers = "TribalUsers"
    public static let ICloudRecordName = "iCloudRecordName"
    public static let UsernameField = "username"
    public static let RegistrationDateField = "registrationDate"
    
    private func fetchTribalUsername(_ database: CKDatabase, recordID: CKRecordID, completionHandler: @escaping (Void) -> (Void)) {
    
        let predicate = NSPredicate(format:"%K == %@", AccountController.ICloudRecordName, recordID.recordName)
        let query = CKQuery(recordType: AccountController.TribalUsers, predicate: predicate)
        database.perform(query, inZoneWith: nil) { (results, error) -> Void in
            
            defer {
                completionHandler()
            }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            if results == nil || results?.count == 0 {
                print("No records found for \(AccountController.ICloudRecordName): \(recordID.recordName)")
                return
            }
            
            if error == nil, let result = results?.first, let username = result.object(forKey: AccountController.UsernameField) as? String {
                // Check if this is different than the current account, if set.
                
                if let current = self.currentAccount {
                    if current.recordName == recordID.recordName &&  current.user.username == username {
                        // No need to update the currentAccount
                        return
                    }
                }
                self.currentAccount = Account(recordName: recordID.recordName, username: username)
            }
        }
    }
    
    @objc private func identityDidChange() {
        updateAccountStatus()
    }

}
