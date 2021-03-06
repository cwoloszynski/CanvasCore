//
//  RemoteCursorsController.swift
//  CanvasCore
//
//  Created by Sam Soffes on 8/8/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import UIKit
import X
import CanvasKit

public protocol RemoteCursorsControllerDelegate: class {
	func remoteCursorsController(_ controller: RemoteCursorsController, rectsForCursor cursor: Cursor) -> [CGRect]
}


/// Controller for background and foreground views for drawing remote cursors.
public final class RemoteCursorsController {

	// MARK: - Types

	fileprivate struct RemoteCursor {
		let username: String
		let color: Color
		var cursor: Cursor
		var lineLayers = [CALayer]()

		let usernameLabel: UILabel = {
			let label = UILabel()
			label.font = .boldSystemFont(ofSize: 8)
			label.textColor = Swatch.black
			label.textAlignment = .center
			return label
		}()

		init(username: String, color: UIColor, cursor: Cursor) {
			self.username = username
			self.color = color
			self.cursor = cursor

			usernameLabel.backgroundColor = color
			usernameLabel.text = username

			// Layout username
			usernameLabel.sizeToFit()
			var size = usernameLabel.frame.size
			size.width += 4
			size.height += 4
			usernameLabel.frame = CGRect(origin: .zero, size: size)
		}
	}


	// MARK: - Initializers

	public init() {
		updateEnabled()
	}
	

	// MARK: - Properties

	public var enabled = false {
		didSet {
			if enabled != oldValue {
				updateEnabled()
			}
		}
	}

	public weak var delegate: RemoteCursorsControllerDelegate?

	public var contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
	public let backgroundView: UIView = {
		let view = UIView()
		view.isUserInteractionEnabled = false
		view.backgroundColor = .white // TODO: Get from theme
		return view
	}()

	public let foregroundView: UIView = {
		let view = UIView()
		view.isUserInteractionEnabled = false
		view.backgroundColor = .clear
		return view
	}()

	// TODO: Get colors from theme
	fileprivate let colors = [
		Color(red: 250 / 255, green: 227 / 255, blue: 224 / 255, alpha: 1),
		Color(red: 250 / 255, green: 242 / 255, blue: 178 / 255, alpha: 1),
		Color(red: 236 / 255, green: 183 / 255, blue: 235 / 255, alpha: 1),
		Color(red: 1, green: 226 / 255, blue: 184 / 255, alpha: 1),
		Color(red: 196 / 255, green: 220 / 255, blue: 225 / 255, alpha: 1),
		Color(red: 1, green: 211 / 255, blue: 200 / 255, alpha: 1)
	]

	// Array of all user IDs that we've seen. We use this to increment the color when a new user joins.
	fileprivate var userIDs = [String]()

	fileprivate var anonymousUserCount: UInt = 0

	// Mapping of user IDs to a remote cursor model.
	fileprivate var remoteCursors = [String: RemoteCursor]()


	// MARK: - Updating

	public func change(user: User, cursor: Cursor) {
		let key = user.id

		// Track this user ID
		let keyIndex: Int
		if let index = userIDs.index(of: key) {
			keyIndex = index
		} else {
			keyIndex = userIDs.count
			userIDs.append(key)
		}

		var remoteCursor: RemoteCursor

		// Already exists
		if var current = remoteCursors[key] {
			if current.cursor == cursor {
				remoteCursors[key] = layoutLayers(remoteCursor: current)
				return
			}
			current.cursor = cursor
			remoteCursor = current
		}

		// New user
		else {
			let username: String

			if let uname = user.username {
				username = uname
			} else {
				anonymousUserCount += 1
				username = "Anonymous \(anonymousUserCount)"
			}
			remoteCursor = RemoteCursor(username: username, color: colors[keyIndex % colors.count], cursor: cursor)
		}

		// Layout updated cursor
		remoteCursor = layoutLayers(remoteCursor: remoteCursor)
		remoteCursors[key] = remoteCursor
	}

	public func leave(user: User) {
		guard let remoteCursor = remoteCursors.removeValue(forKey: user.id) else { return }
		removeLayers(remoteCursor: remoteCursor)
		remoteCursor.usernameLabel.removeFromSuperview()
	}

	public func updateLayout() {
		if !enabled {
			return
		}
		
		for (key, remoteCursor) in remoteCursors {
			remoteCursors[key] = layoutLayers(remoteCursor: remoteCursor)
		}
	}


	// MARK: - Private

	fileprivate func removeLayers(remoteCursor: RemoteCursor) {
		remoteCursor.lineLayers.forEach { layer in
			layer.isHidden = true
			layer.removeFromSuperlayer()
		}
	}

	fileprivate func layoutLayers(remoteCursor: RemoteCursor) -> RemoteCursor {
		removeLayers(remoteCursor: remoteCursor)

		var remoteCursor = remoteCursor
		remoteCursor.lineLayers = []

		guard let rects = delegate?.remoteCursorsController(self, rectsForCursor: remoteCursor.cursor) else {
			remoteCursor.usernameLabel.removeFromSuperview()
			return remoteCursor
		}

		if rects.isEmpty {
			return remoteCursor
		}

		// Setup line layers
		remoteCursor.lineLayers = rects.map { rect in
			let layer = CALayer()
			layer.backgroundColor = remoteCursor.color.cgColor

			var rect = rect
			rect.origin.x += contentInset.left
			rect.origin.y += contentInset.top
			rect.size.width = max(2, rect.size.width)
			layer.frame = rect

			return layer
		}

		// Add the line layers to the view
		remoteCursor.lineLayers.forEach { layer in
			backgroundView.layer.addSublayer(layer)
		}

		// Layout the label layer
		let firstLine = remoteCursor.lineLayers[0]

		var frame = remoteCursor.usernameLabel.frame
		frame.origin.x = firstLine.frame.minX
		frame.origin.y = firstLine.frame.minY - frame.height
		remoteCursor.usernameLabel.frame = frame

		// Add the label layer
		if remoteCursor.usernameLabel.superview == nil {
			foregroundView.addSubview(remoteCursor.usernameLabel)
		}

		// Add label animation
		animateLabel(remoteCursor: remoteCursor)

		return remoteCursor
	}

	fileprivate func animateLabel(remoteCursor: RemoteCursor) {
		let animation = CABasicAnimation(keyPath: "opacity")
		animation.fillMode = kCAFillModeForwards
		animation.isRemovedOnCompletion = false
		animation.duration = 0.2
		animation.beginTime = CACurrentMediaTime() + 1
		animation.fromValue = 1
		animation.toValue = 0
		remoteCursor.usernameLabel.layer.removeAnimation(forKey: "opacity")
		remoteCursor.usernameLabel.layer.add(animation, forKey: "opacity")
	}

	fileprivate func updateEnabled() {
		backgroundView.isHidden = !enabled
		foregroundView.isHidden = !enabled
		updateLayout()
	}
}
