//
//  PresenceController.swift
//  CanvasCore
//
//  Created by Sam Soffes on 6/1/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import CanvasKit
import CanvasNative
// import Starscream

#if !os(OSX)
	import UIKit
#endif

public protocol PresenceObserver: NSObjectProtocol {
	func presenceController(_ controller: PresenceController, canvasID: String, userJoined user: User, cursor: Cursor?)
	func presenceController(_ controller: PresenceController, canvasID: String, user: User, updatedCursor cursor: Cursor?)
	func presenceController(_ controller: PresenceController, canvasID: String, userLeft user: User)
}


// TODO: Update meta
// TODO: Handle update meta
// TODO: Handle expired
open class PresenceController: Accountable {

	// MARK: - Types

	fileprivate struct Client {
		let id: String
		let user: User
		var cursor: Cursor?

		init?(dictionary: JSONDictionary) {
			guard let id = dictionary["id"] as? String,
				let user = (dictionary["user"] as? JSONDictionary).flatMap(User.init)
			else { return nil }

			self.id = id
			self.user = user

			let meta = dictionary["meta"] as? JSONDictionary
			cursor = (meta?["cursor"] as? JSONDictionary).flatMap(Cursor.init)
		}
	}

	fileprivate struct Connection {
		let canvasID: String
		let connectionID: String
		var cursor: Cursor?
		var clients = [Client]()

		init(canvasID: String, connectionID: String = NSUUID().uuidString.lowercased()) {
			self.canvasID = canvasID
			self.connectionID = connectionID
		}
	}


	// MARK: - Properties

	open var account: Account
	open let serverURL: URL

	open var isConnected: Bool {
        return false
		// return socket?.isConnected ?? false
	}

//	fileprivate var socket: WebSocket? = nil
	fileprivate var connections = [String: Connection]()
	fileprivate var messageQueue = [JSONDictionary]()
	fileprivate var pingTimer: Timer?
	fileprivate var observers = NSMutableSet()


	// MARK: - Initializers

	public init(account: Account, serverURL: URL) {
		self.account = account
		self.serverURL = serverURL

		connect()

		#if !os(OSX)
			let notificationCenter = NotificationCenter.default
			notificationCenter.addObserver(self, selector: #selector(applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
			notificationCenter.addObserver(self, selector: #selector(applicationWillEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
		#endif
	}

	deinit {
		observers.removeAllObjects()
		disconnect()
	}


	// MARK: - Connecting

	open func connect() {
        
/*
		if socket != nil {
			return
		}

		guard let url = URL(string: "socket/websocket", relativeTo: serverURL),
			let path = bundle.path(forResource: "STAR_usecanvas_com", ofType: "der"),
			let data = try? Data(contentsOf: URL(fileURLWithPath: path))
		else { */
			print("[CanvasCore] Presence failed to setup a WebSocket connection.")
			return
	/*	}
 */
        

/* 		let ws = WebSocket(url: url)
		ws.security = SSLSecurity(certs: [SSLCert(data: data)], usePublicKeys: true)
		ws.origin = "https://usecanvas.com"
		ws.delegate = self
		ws.connect()

		socket = ws
 */
	}

	open func disconnect() {
		for (_, connection) in connections {
			leave(canvasID: connection.canvasID)
		}

/* 		socket?.disconnect()
		socket = nil
 
 */
	}


	// MARK: - Working with Canvases

	open func join(canvasID: String) {
		let connection = Connection(canvasID: canvasID)

		connections[canvasID] = connection

		sendJoinMessage(connection)
	}

	open func leave(canvasID: String) {
		guard let connection = connections[canvasID] else { return }

		sendMessage([
			"event": "phx_leave" as AnyObject,
			"topic": "presence:canvases:\(connection.canvasID)" as AnyObject,
			"payload": [:] as AnyObject,
			"ref": "4" as AnyObject
		])

		connections.removeValue(forKey: canvasID)
	}

	open func update(selection presentationSelectedRange: NSRange?, withDocument document: Document, canvasID: String) {
		guard let connection = connections[canvasID] else { return }

		var payload = [String: AnyObject]()

		if let selection = presentationSelectedRange, let cursor = Cursor(presentationSelectedRange: selection, document: document) {
			payload["cursor"] = cursor.dictionary as AnyObject
		}

		sendMessage([
			"event": "update_meta" as AnyObject,
			"topic": "presence:canvases:\(connection.canvasID)" as AnyObject,
			"payload": payload as AnyObject,
			"ref": "3" as AnyObject
		])
	}


	// MARK: - Notifications

	open func add(observer: PresenceObserver) {
		observers.add(observer)
	}

	open func remove(observer: PresenceObserver) {
		observers.remove(observer)
	}


	// MARK: - Querying

	open func users(canvasID: String) -> [User] {
		return clients(canvasID: canvasID).map { $0.user }
	}


	// MARK: - Private

	@objc fileprivate func applicationWillEnterForeground() {
		if connections.isEmpty {
			return
		}

		connect()
		connections.values.forEach(sendJoinMessage)
		setupPingTimer()
	}

	@objc fileprivate func applicationDidEnterBackground() {
		pingTimer?.invalidate()
		pingTimer = nil

/*
		socket?.disconnect()
		socket = nil
 */
	}

	fileprivate func clients(canvasID: String) -> [Client] {
		guard let connection = connections[canvasID] else { return [] }

		var seen = Set<User>()
		var clients = [Client]()

		for client in connection.clients {
			if seen.contains(client.user) {
				continue
			}

			seen.insert(client.user)
			clients.append(client)
		}

		return clients
	}

	fileprivate func sendJoinMessage(_ connection: Connection) {
		let payload = clientDescriptor(connectionID: connection.connectionID)

		sendMessage([
			"event": "phx_join" as AnyObject,
			"topic": "presence:canvases:\(connection.canvasID)" as AnyObject,
			"payload": payload as AnyObject,
			"ref": "1" as AnyObject
		])
	}

	fileprivate func setupPingTimer() {
		if pingTimer != nil {
			return
		}

		let timer = Timer(timeInterval: 20, target: self, selector: #selector(ping), userInfo: nil, repeats: true)
		timer.tolerance = 10
		RunLoop.current.add(timer, forMode: RunLoopMode.defaultRunLoopMode)
		pingTimer = timer
	}

	fileprivate func sendMessage(_ message: JSONDictionary) {
        /*
		if let socket = socket, socket.isConnected {
			if let data = try? JSONSerialization.data(withJSONObject: message, options: []) {
				socket.writeData(data)
			}
		} else {
			messageQueue.append(message)
			connect()
		}
 */
	}

	fileprivate func clientDescriptor(connectionID: String) -> JSONDictionary {
		return [
			"id": connectionID as AnyObject,
			"user": account.user.dictionary as AnyObject,

			// TODO: Meta
			"meta": [:] as AnyObject
		]
	}

	@objc fileprivate func ping() {
		for (_, connection) in connections {
			sendMessage([
				"event": "ping" as AnyObject,
				"topic": "presence:canvases:\(connection.canvasID)" as AnyObject,
				"payload": [:] as AnyObject,
				"ref": "2" as AnyObject
			])
		}
	}

	fileprivate func presenceController(_ controller: PresenceController, canvasID: String, userJoined user: User, cursor: Cursor?) {
		for observer in observers {
			guard let observer = observer as? PresenceObserver else { continue }
			observer.presenceController(self, canvasID: canvasID, userJoined: user, cursor: cursor)
		}
	}

	fileprivate func presenceController(_ controller: PresenceController, canvasID: String, user: User, updatedCursor cursor: Cursor?) {
		for observer in observers {
			guard let observer = observer as? PresenceObserver else { continue }
			observer.presenceController(self, canvasID: canvasID, user: user, updatedCursor: cursor)
		}
	}

	fileprivate func presenceController(_ controller: PresenceController, canvasID: String, userLeft user: User) {
		for observer in observers {
			guard let observer = observer as? PresenceObserver else { continue }
			observer.presenceController(self, canvasID: canvasID, userLeft: user )
		}
	}
}


/* extension PresenceController: WebSocketDelegate {
	public func websocketDidConnect(_ socket: WebSocket) {
		for message in messageQueue {
			if let data = try? NSJSONSerialization.dataWithJSONObject(message, options: []) {
				socket.writeData(data)
			}
		}

		messageQueue.removeAll()

		setupPingTimer()
	}

	public func websocketDidDisconnect(_ socket: WebSocket, error: NSError?) {
		pingTimer?.invalidate()
		pingTimer = nil
	}

	public func websocketDidReceiveMessage(_ socket: WebSocket, text: String) {
		guard let data = text.data(using: String.Encoding.utf8),
			let raw = try? JSONSerialization.jsonObject(with: data, options: []),
			let json = raw as? JSONDictionary,
			let event = json["event"] as? String,
			let topic = json["topic"] as? String,
			let payload = json["payload"] as? JSONDictionary
		else { return }

		let canvasID = topic.stringByReplacingOccurrencesOfString("presence:canvases:", withString: "")
		guard var connection = connections[canvasID] else { return }

		// Join
		if event == "phx_reply", let response = payload["response"] as? JSONDictionary, let clients = response["clients"] as? [JSONDictionary] {
			let clients = clients.flatMap(Client.init).filter { $0.user != account.user }

			if !clients.isEmpty {
				connection.clients = clients
				connections[canvasID] = connection

				for client in self.clients(canvasID: canvasID) {
					presenceController(self, canvasID: canvasID, userJoined: client.user, cursor: client.cursor)
				}
			}
		}

		// Remote join
		else if event == "remote_join", let client = Client(dictionary: payload), client.user != account.user {
			var clients = connection.clients ?? []
			let before = Set(clients.map { $0.user })

			clients.append(client)
			connection.clients = clients
			connections[canvasID] = connection

			let after = Set(clients.map { $0.user })
			if before != after {
				presenceController(self, canvasID: canvasID, userJoined: client.user, cursor: client.cursor)
			}
		}

		// Remove leave
		else if event == "remote_leave", let client = Client(dictionary: payload), client.user != account.user {
			var clients = connection.clients ?? []
			let before = Set(clients.map { $0.user })

			if let index = clients.indexOf({ $0.id == client.id }) {
				clients.removeAtIndex(index)
				connection.clients = clients
				connections[canvasID] = connection
			}

			let after = Set(clients.map { $0.user })
			if before != after {
				presenceController(self, canvasID: canvasID, userLeft: client.user)
			}
		}

		// Remote update
		else if event == "remote_update", let updatedClient = Client(dictionary: payload), updatedClient.user != account.user {
			var clients = connection.clients ?? []
			if let index = clients.indexOf({ $0.id == updatedClient.id }) {
				let previousClient = clients[index]
				clients.removeAtIndex(index)
				clients.insert(updatedClient, atIndex: index)
				connection.clients = clients
				connections[canvasID] = connection

				if previousClient.cursor != updatedClient.cursor {
					presenceController(self, canvasID: canvasID, user: updatedClient.user, updatedCursor: updatedClient.cursor)
				}
			}
		}
	}

	public func websocketDidReceiveData(_ socket: WebSocket, data: Data) {}
} */
