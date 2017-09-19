//
//  ProjectController.swift
//  TeamCanvas
//
//  Created by Charlie Woloszynski on 6/26/17.
//  Copyright © 2017 Handheld Media, LLC. All rights reserved.
//

import UIKit
import CanvasKit

public class ProjectsController : NSObject { // Inherit from NSObject to suport UITableViewDataSource inheritance
    
    static let defaultFilename = "projectList.json"
    
    static public let `default` = ProjectsController(filename:defaultFilename)
    
    public enum Keys {
        static let version = "version"
        static let elements = "elements"
    }
    
    private enum UserKeys {
        public static let selectedProjectId = "selectedProjectId"
    }


    // FIXME: The projects array needs to be managed so changes to it (append, remove) trigger a write to the filesystem.
    
    public var projects = [Project]()
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
        
        self.url = ProjectsController.targetDirectoryURL.appendingPathComponent(filename)
        super.init()
        
        do {
            try parseFile()
        } catch {
            print("Error initializating")
            try? writeFile()
        }
    }
    
    public func setSelectedProject(_ project: Project?) {
        if let project = project {
            DispatchQueue.main.async {
                UserDefaults.standard.set(project.id, forKey: ProjectsController.UserKeys.selectedProjectId)
                UserDefaults.standard.synchronize()
            }
        } else {
            DispatchQueue.main.async {
                UserDefaults.standard.removeObject(forKey: ProjectsController.UserKeys.selectedProjectId)
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    public func getSelectedProject() -> Project {
        if let id = UserDefaults.standard.string(forKey: ProjectsController.UserKeys.selectedProjectId) {
            if let project = projects.first(where: { $0.id == id }) {
                return project
            }
        }
        return createPersonalProject()
    }
    
    public func insert(_ project: Project, at index:Int) {
    
        projects.insert(project, at: index)
    }
    
    public func remove(at index: Int) -> Project {
        
        return projects.remove(at: index)
    }
    
    public func exchange(_ indexA: Int, with indexB: Int) {
        let projectA = projects[indexA]
        let projectB = projects[indexB]
        projects.remove(at: indexA)
        projects.insert(projectB, at: indexA)
        projects.remove(at: indexB)
        projects.insert(projectA, at: indexB)
    }
    
    public func rename(at index: Int, name: String) {
        projects[index].name = name
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
        
        projects.removeAll()
        
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
                if let projectJson = element as? [String: Any] {
                    if let project = Project(dictionary: projectJson as JSONDictionary) {
                        projects.append(project)
                    }
                }
            }
        }
        
        let personal = projects.first { $0.isPersonal }
        if personal == nil {
            projects.insert(createPersonalProject(), at: 0)
        }
    }
    
    private func createPersonalProject() -> Project {
        let dict: [String: Any] = ["id": "123", "slug": "abc", "name": "Personal", "members_count": UInt(1), "isPersonal": true,  "color": "#808080"]
        let jsonDict = dict as JSONDictionary
        return Project(dictionary: jsonDict)!
    }
    private func writeFile() throws {
        
        var jsonProjects = [[String:Any]]()
        
        for project in projects {
            if let jsonProject = project.toJSON() {
                jsonProjects.append(jsonProject)
            }
        }
        
        let json = [Keys.version: "1",
                    Keys.elements: jsonProjects] as [String : Any]
        
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


