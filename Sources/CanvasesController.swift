//
//  CanvasesController.swift
//  TeamCanvas
//
//  Created by Charlie Woloszynski on 9/21/17.
//  Copyright © 2017 Handheld Media, LLC. All rights reserved.
//

import UIKit
import CanvasKit
import CanvasNative

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
    
    private let project: Project
    
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
    
    public init(project: Project) {
        self.project = project
        
        self.filename = project.id
        
        self.url = CanvasesController.targetDirectoryURL.appendingPathComponent(filename).appendingPathComponent("canvasList.json")
        super.init()
        
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                try parseFile()
            } else {
                try? writeFile()
            }
        } catch let error {
            print("Error initializing Canvases Controller: \(error.localizedDescription)")
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
        // FIXME:  This ! might be dangerous if the getSelectedCanvas happens after the
        // last canvas is deleted.
        //
        return canvases.first!
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
    
    public func update(at index: Int, summary: String) {
        canvases[index].summary = summary
    }
    
    fileprivate func toggleWriteLock(at index: Int) {
        canvases[index].isWritable = !canvases[index].isWritable
    }
    
    public func persistData() {
        do {
            try writeFile()
        } catch {
            // FIXME: Need to handle this better.  Perhaps inform the user and reset the project data
            print("Error persisting the data")
        }
    }
    
    public func refresh(_ completionHandler: @escaping ((Result<[Canvas]>) -> Void)) {
    
    
        // FIXME:  This should refresh the canvases and call back
        // async, but right now we just do the following.
    
        DispatchQueue.main.async {
            completionHandler(.success(self.canvases))
        }
    }
    
    public func createBlankCanvas(_ completion: @escaping ((Result<Canvas>)-> Void)) {
        
        DispatchQueue.main.async {
            
            let now = NSDate().iso8601String()!
            let uuid = UUID().uuidString.lowercased()
            let id = "canvas-\(uuid)"
            let dict: [String: Any] = [Canvas.Keys.Id: id,
                                       Canvas.Keys.ProjectId: self.project.id,
                                       Canvas.Keys.IsWritable: true,
                                       Canvas.Keys.IsPublicWritable: true,
                                       Canvas.Keys.UpdatedAt: now,
                                       Canvas.Keys.Title: "Untitled",
                                       Canvas.Keys.Summary: "",
                                       Canvas.Keys.NativeVersion: "0.0.0"
                
                                        ]
            let jsonDict = dict as JSONDictionary
            guard let canvas = Canvas(dictionary: jsonDict) else { fatalError("Creating blank canvas") }
            self.insert(canvas, at: 0)
            completion(.success(canvas))
        }
    }
    
    public func archive(canvas: Canvas, completion: @escaping ((Result<Canvas>)-> Void)) {
        
        // FIXME: This needs a real implementation
        
        DispatchQueue.main.async {
            completion(.success(canvas))
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
            print("Canvases file written at \(url.path)")
        }
    }
    
    public func toggleWriteLock(forCanvasId canvasId: String) -> IndexPath? {
        if let index = canvases.index(where: { $0.id == canvasId }) {
            toggleWriteLock(at: index)
            // FIXME: Not sure I like the try! below
            try! writeFile()
            return IndexPath(row: index, section: 0)
        } else {
            print("ID not found when toggling the writelock for a canvas with ID: \(canvasId)")
            return nil
        }
    }
    
    // MARK: CanvasesChangeDelegate
    public func didUpdate(title: String, forCanvasId canvasId: String) -> IndexPath? {
        if let index = canvases.index(where: { $0.id == canvasId }) {
            rename(at: index, title: title)
            // FIXME: Not sure I like the try! below
            try! writeFile()
            return IndexPath(row: index, section: 0)
        } else {
            print("ID not found when renaming a canvas with ID: \(canvasId)")
            return nil
        }
    }

    public func didUpdate(summary: String, forCanvasId canvasId: String) -> IndexPath? {
        if let index = canvases.index(where: { $0.id == canvasId }) {
            update(at: index, summary: summary)
            // FIXME: Not sure I like the try! below
            try! writeFile()
            return IndexPath(row: index, section: 0)
        } else {
            print("ID not found when updating summary a canvas with ID: \(canvasId)")
            return nil
        }
    }
}


