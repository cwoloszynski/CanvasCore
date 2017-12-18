//
//  UIColor+HexExtensions.swift
//
//  Created by Charlie Woloszynski on 2/9/15.
//  Copyright (c) 2015 Handheld Media, LLC. All rights reserved.
//

import UIKit

extension UIColor {
    
    convenience init(hex: Int) {
        
        let components = (
            R: CGFloat((hex >> 16) & 0xff) / 255,
            G: CGFloat((hex >> 08) & 0xff) / 255,
            B: CGFloat((hex >> 00) & 0xff) / 255
        )
        
        self.init(red: components.R, green: components.G, blue: components.B, alpha: 1)
        
    }
    
    convenience  init (hexString:String) {
        var cString:String = hexString.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines).uppercased()
        
        if let index = cString.index(of: "#") {
            cString = String(cString[index...])
        }
        
        if (cString.count != 6) {
            self.init(red:0.5, green:0.5, blue:0.5, alpha: 1.0)
            return;
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    
}
