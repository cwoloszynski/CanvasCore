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
				UserDefaults.standard.removeObject(forKey: "Organizations")
				UserDefaults.standard.removeObject(forKey: "SelectedOrganization")
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
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        
        database.save(record) { (record, error) -> Void in
            
            if let error = error {
                // FIXME:  This needs to handle errors better.
                let errorMsg = "Unspecified Error: \(error.localizedDescription)"
                completion(errorMsg)
            }
            
            let account = Account(recordID: recordID, username: username)
            DispatchQueue.main.async {
                self.currentAccount = account
                completion(nil)
            }
        }
    }
    
    private func updateAccountStatus() {
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
                let account = Account(recordID: recordID, username: username)
                self.currentAccount = account
            }
        }
    }
    
    @objc private func identityDidChange() {
        updateAccountStatus()
    }

}
