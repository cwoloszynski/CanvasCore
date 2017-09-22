//
//  CanvasesController.swift
//  TeamCanvas
//
//  Created by Charlie Woloszynski on 9/21/17.
//  Copyright © 2017 Handheld Media, LLC. All rights reserved.
//

import UIKit
import CanvasKit

public class CanvasesController : NSObject { // Inherit from NSObject to suport UITableViewDataSource inheritance
    
    // static let defaultFilename = "projectList.json"
    
    // static public let `default` = ProjectsController(filename:defaultFilename)
    
    public enum Keys {
        static let version = "version"
        static let elements = "elements"
    }
    
    private enum UserKeys {
        public static let selectedCanvasId = "selectedCanvasId"
    }


    // FIXME: The projects array needs to be managed so changes to it (append, remove) trigger a write to the filesystem.
    
    public var canvases = [Canvas]()
    public private(set) var filename: String
    
    static let targetDirectoryURL: URL = { () -> URL in
        let fileManager = FileManager.default
        guard let url = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            // This should only throw an error if the arguements are nonsensical
            // So, we simply abort the code if this happens
            fatalError()
        }
        return url
    }()
    
    private var url: URL
    
    init(filename: String) {
        self.filename = filename
        
        self.url = CanvasesController.targetDirectoryURL.appendingPathComponent(filename)
        super.init()
        
        do {
            try parseFile()
        } catch {
            print("Error initializating Canvases Controller")
            try? writeFile()
        }
    }
    
    public func setSelectedCanvas(_ canvas: Canvas?) {
        if let canvas = canvas {
            DispatchQueue.main.async {
                UserDefaults.standard.set(canvas.id, forKey: CanvasesController.UserKeys.selectedCanvasId)
                UserDefaults.standard.synchronize()
            }
        } else {
            DispatchQueue.main.async {
                UserDefaults.standard.removeObject(forKey: CanvasesController.UserKeys.selectedCanvasId)
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    public func getSelectedCanvas() -> Canvas {
        if let id = UserDefaults.standard.string(forKey: CanvasesController.UserKeys.selectedCanvasId) {
            if let canvas = canvases.first(where: { $0.id == id }) {
                return canvas
            }
        }
        return createBlankCanvas()
    }
    
    public func insert(_ canvas: Canvas, at index:Int) {
    
        canvases.insert(canvas, at: index)
    }
    
    public func remove(at index: Int) -> Canvas {
        
        return canvases.remove(at: index)
    }
    
    public func exchange(_ indexA: Int, with indexB: Int) {
        let canvasA = canvases[indexA]
        let canvasB = canvases[indexB]
        canvases.remove(at: indexA)
        canvases.insert(canvasB, at: indexA)
        canvases.remove(at: indexB)
        canvases.insert(canvasA, at: indexB)
    }
    
    public func rename(at index: Int, title: String) {
        canvases[index].title = title
    }
    
    public func persistData() {
        do {
            try writeFile()
        } catch {
            // FIXME: Need to handle this better.  Perhaps inform the user and reset the project data
            print("Error persisting the data")
        }
    }
    
    private func parseFile() throws {
        
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
                throw SerializationError.missingFile
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw SerializationError.invalidJson
        }
        
        canvases.removeAll()
        
        guard let version = json[Keys.version] as? String else {
            throw SerializationError.missing(Keys.version)
        }
        
        // We start only handling version '1', but this will grow as the file format changes
        if version != "1" {
            print("Unsupported version")
            fatalError()
        }
        
        if let elements = json[Keys.elements] as? [Any] {
            for element in elements {
                if let canvasJson = element as? [String: Any] {
                    if let canvas = Canvas(dictionary: canvasJson as JSONDictionary) {
                        canvases.append(canvas)
                    }
                }
            }
        }
    }
    
    private func createBlankCanvas() -> Canvas {
        let dict: [String: Any] = ["id": "123"]
        let jsonDict = dict as JSONDictionary
        return Canvas(dictionary: jsonDict)!
    }
    private func writeFile() throws {
        
        var jsonCanvases = [[String:Any]]()
        
        for canvas in canvases {
            if let jsonCanvas = canvas.toJSON() {
                jsonCanvases.append(jsonCanvas)
            }
        }
        
        let json = [Keys.version: "1",
                    Keys.elements: jsonCanvases] as [String : Any]
        
        guard let data =  try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            throw SerializationError.invalidJson
        }
            
        // Since we want overwrite this file, we can use the
        // basic functionality here and create over the old file
        let fileManager = FileManager.default
        
        if !fileManager.createFile(atPath: url.path, contents: data, attributes: [:]) {
            print("Error creating file at \(url.path)")
        } else {
            print("File created at \(url.path)")
        }
    }
}


