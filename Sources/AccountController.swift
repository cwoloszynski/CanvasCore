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

    public enum Keys {
        public static let TribalUsers = "TribalUsers"
        public static let CloudRecordName = "CloudRecordName"
        public static let UsernameField = "username"
        public static let RegistrationDateField = "registrationDate"
    }

    public private(set) var isCloudKitEnabled: Bool = false
    
	open var currentAccount: Account? {
        didSet {
 
            accountNeverSet = false
            
            let userDefaults = UserDefaults.standard
            if let account = currentAccount {
                DispatchQueue.main.async {
                    userDefaults.set(account.user.username, forKey: AccountController.Keys.UsernameField)
                    userDefaults.set(account.recordName, forKey: AccountController.Keys.CloudRecordName)
                    userDefaults.synchronize()
                }
            } else {
                DispatchQueue.main.async {
                    userDefaults.removeObject(forKey: AccountController.Keys.UsernameField)
                    userDefaults.removeObject(forKey: AccountController.Keys.CloudRecordName)
                    userDefaults.synchronize()
                }
            }

            // Make sure we do this on the main thread, since this call seems to propagate the
            // event on the same thread as it is posted on.
            print("notifying of change in 'currentAccount'")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AccountController.accountDidChangeNotification, object: nil)
            }
		}
	}

	open static let accountDidChangeNotification = Notification.Name(rawValue: "AccountController.accountDidChangeNotification")

    open static let cloudKitStatusUpdatedNotification = Notification.Name(rawValue: "AccountController.cloudKitStatusUpdated")
    
	open static let sharedController = AccountController()

    private var group: DispatchGroup
    private var recordID: CKRecordID?
    
    private var accountNeverSet = true

	// MARK: - Initializers

	init() {
        
        group = DispatchGroup()
        
//        NotificationCenter.default.addObserver(self, selector: #selector(identityDidChange), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(identityDidChange), name: NSNotification.Name.CKAccountChanged, object: nil)
        
        updateAccountStatus()
        
        return
	}
    
    public func createLocalAccount() {
        let account = Account(recordName: "", username: "Local")
        self.currentAccount = account
    }
    
    public func createAccount(username: String, completion: @escaping (String?) -> Void) {
        
        guard let recordID = recordID else {
            completion("An iCloud account is needed to create a Tribal username")
            return
        }
        
        let record = CKRecord(recordType: AccountController.Keys.TribalUsers)
        record[AccountController.Keys.CloudRecordName] = recordID.recordName as CKRecordValue
        record[AccountController.Keys.UsernameField] = username as CKRecordValue
        record[AccountController.Keys.RegistrationDateField] = NSDate() as CKRecordValue
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
                
                let predicate = NSPredicate(format:"%K == %@", AccountController.Keys.UsernameField, username)
                let query = CKQuery(recordType: AccountController.Keys.TribalUsers, predicate: predicate)
                query.sortDescriptors = [NSSortDescriptor(key: AccountController.Keys.RegistrationDateField, ascending: true)]
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
                    
                    let firstCreated = first[AccountController.Keys.CloudRecordName] as? String
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
        
        let username = UserDefaults.standard.string(forKey: AccountController.Keys.UsernameField)
        let recordName = UserDefaults.standard.string(forKey: AccountController.Keys.CloudRecordName)
        
        // If we know the current account information, create an account and set it
        if let username = username, let recordName = recordName {
            let account = Account(recordName: recordName, username: username)
            self.currentAccount = account
        }
        
        // Only check on account status if the account is a CloudKit account.  If we already have a local
        // account, we don't need to react to this account change.
        if let account = currentAccount, account.isLocal { return }
        
        // However, if the CloudKit account is no longer available, we need to know this
        // and adjust the app's behavior.  If the account is no longer available, the account 
        // will be set to nil.  This may cause the RootViewController to start on-boarding again!
        
        let container = CKContainer.default()
        group.enter()
        container.fetchUserRecordID { (recordID, error) -> Void in
            if error == nil, let recordID = recordID {
                self.recordID = recordID
                self.fetchTribalUsername(container.publicCloudDatabase, recordID: recordID) { () -> Void in
                    // print("notifying of CloudKit update")
                    self.isCloudKitEnabled = true
                    NotificationCenter.default.post(name: AccountController.cloudKitStatusUpdatedNotification, object: nil)
                    self.group.leave()
                }
            } else {
                // Error in getting the user's ID. Either we are not logged into iCloud or the network comms are broken.
                // Let's determine the issue.
                
                CKContainer.default().accountStatus { (accountStatus, error) in
                    switch accountStatus {
                        
                    case .available:
                        print("iCloud Available")
                        self.isCloudKitEnabled = true
                    case .noAccount:
                        print("no iCloud Account")
                        // set the account to nil to start the onboarding process
                        if self.currentAccount != nil || self.accountNeverSet {
                            self.currentAccount = nil
                        }
                        self.isCloudKitEnabled = false
                    case .couldNotDetermine:
                        print("Could not determine")
                        self.isCloudKitEnabled = false
                    case .restricted:
                        print("Restricted")
                        self.isCloudKitEnabled = false
                    }
                    NotificationCenter.default.post(name: AccountController.cloudKitStatusUpdatedNotification, object: nil)
                    self.group.leave()
                }
            }
        }
    }
    
    
    private func fetchTribalUsername(_ database: CKDatabase, recordID: CKRecordID, completionHandler: @escaping () -> (Void)) {
    
        let predicate = NSPredicate(format:"%K == %@", AccountController.Keys.CloudRecordName, recordID.recordName)
        let query = CKQuery(recordType: AccountController.Keys.TribalUsers, predicate: predicate)
        database.perform(query, inZoneWith: nil) { (results, error) -> Void in
            
            defer {
                completionHandler()
            }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            if results == nil || results?.count == 0 {
                // print("No records found for \(AccountController.Keys.CloudRecordName): \(recordID.recordName)")
                // FIXME: May need to delete locally cached data when this happens, or when a new username is registered
                // Not sure yet, since the iCloud account is still logged in.  
                if self.currentAccount != nil || self.accountNeverSet {
                    self.currentAccount = nil
                }
                return
            }
            
            if error == nil, let result = results?.first, let username = result.object(forKey: AccountController.Keys.UsernameField) as? String {
                // Check if this is different than the current account, if set.
                
                if let current = self.currentAccount {
                    if current.recordName == recordID.recordName && current.user.username == username {
                        // No need to update the currentAccount
                        // print("learned of same account controller as 'currentAccount'")
                        return
                    }
                }
                // print("setting new 'currentAccount'")
                self.currentAccount = Account(recordName: recordID.recordName, username: username)
            }
        }
    }
    
    @objc private func identityDidChange() {
        // print("identity did change")
        updateAccountStatus()
    }

}
