//
//  Swatch.swift
//  CanvasCore
//
//  Created by Sam Soffes on 11/12/15.
//  Copyright © 2015–2016 Canvas Labs, Inc. All rights reserved.
//

import X

public struct Swatch {

	// MARK: - Base

	public static let black = Color(red: 0.161, green: 0.180, blue: 0.192, alpha: 1)
	public static let white = Color.white
	public static let darkGray = Color(red: 0.35, green:0.35, blue: 0.35, alpha: 1)
    public static let warmGray = Color(red: 0.5, green: 0.25, blue: 0.25, alpha: 1)
	public static let gray = Color(red: 0.752, green: 0.796, blue: 0.821, alpha: 1)
	public static let lightGray = Color(red: 0.906, green: 0.918, blue: 0.925, alpha: 1)
	public static let extraLightGray = Color(red: 0.961, green: 0.969, blue: 0.976, alpha: 1)

	public static let blue = Color(red: 0.255, green:0.306, blue: 0.976, alpha: 1)
	public static let lightBlue = Color(red: 0.188, green: 0.643, blue: 1, alpha: 1)
	public static let green = Color(red: 0.157, green:0.859, blue: 0.404, alpha: 1)
	public static let pink = Color(red: 1, green: 0.216, blue: 0.502, alpha: 1)
	public static let yellow = Color(red: 1, green: 0.942, blue: 0.716, alpha: 1)
    public static let red = Color(red:0.976, green: 0.306, blue: 0.255, alpha: 1)
    
    public static let ultraviolet = Color(hex: "#5F4B8B")! // Ultra Violet

	// MARK: - Shared

	public static let brand = ultraviolet
	public static let destructive = red
	public static let comment = yellow


	// MARK: - Bars

	public static let border = gray


	// MARK: - Tables

	public static let groupedTableBackground = extraLightGray

	/// Chevron in table view cells
	public static let cellDisclosureIndicator = darkGray
}
