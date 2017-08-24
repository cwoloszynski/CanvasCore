//
//  AccountController.swift
//  CanvasCore
//
//  Created by Sam Soffes on 11/3/15.
//  Copyright © 2015–2016 Canvas Labs, Inc. All rights reserved.
//

import CanvasKit
// import SAMKeychain

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

			NotificationCenter.default.post(name: Notification.Name(rawValue: type(of: self).accountDidChangeNotificationName), object: nil)
		}
	}

	open static let accountDidChangeNotificationName = "AccountController.accountDidChangeNotification"

	open static let sharedController = AccountController()


	// MARK: - Initializers

	init() {
		/* guard let data = SAMKeychain.passwordDataForService("Canvas", account: "Account") else { return }

		guard let json = try? JSONSerialization.JSONObjectWithData(data, options: []),
			let dictionary = json as? JSONDictionary,
			let account = Account(dictionary: dictionary)
		else {
			SAMKeychain.deletePasswordForService("Canvas", account: "Account")
			return
		}

		currentAccount = account
        */
        return
	}
}
