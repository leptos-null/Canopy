//
//  SystemEntry.swift
//  Canopy
//
//  Created by Leptos on 11/15/25.
//

import Foundation
import System

@MainActor
@Observable
class SystemEntry: Identifiable {
    let id: SystemInformation.ObjectID
    
    private var cachedLabel: Result<String, System.Errno>?
    private var cachedDescription: Result<String, System.Errno>?
    private var cachedMetadata: Result<SystemInformation.ObjectMetadata, System.Errno>?
    private var cachedRawBytes: Result<[UInt8], System.Errno>?
    
    private func testSet<T, E>(cache keyPath: ReferenceWritableKeyPath<SystemEntry, Result<T, E>?>, compute: () throws(E) -> T) -> Result<T, E> {
        if let cacheValue = self[keyPath: keyPath] {
            return cacheValue
        }
        let result: Result<T, E> = .init(catching: compute)
        self[keyPath: keyPath] = result
        return result
    }
    
    init(objectID id: SystemInformation.ObjectID) {
        self.id = id
    }
    
    var label: Result<String, System.Errno> {
        testSet(cache: \.cachedLabel) { () throws(System.Errno) in
            try SystemInformation.label(for: id)
        }
    }
    
    var description: Result<String, System.Errno> {
        testSet(cache: \.cachedDescription) { () throws(System.Errno) in
            try SystemInformation.description(for: id)
        }
    }
    
    var metadata: Result<SystemInformation.ObjectMetadata, System.Errno> {
        testSet(cache: \.cachedMetadata) { () throws(System.Errno) in
            try SystemInformation.metadata(for: id)
        }
    }
    
    var rawBytes: Result<[UInt8], System.Errno> {
        testSet(cache: \.cachedRawBytes) { () throws(System.Errno) in
            try SystemInformation.object(for: id)
        }
    }
    
    var bestEffortValue: Result<SystemInformation.BestEffortValue, System.Errno> {
        .init { () throws(System.Errno) in
            let rawBytes = try self.rawBytes.get()
            let metadata = try? self.metadata.get()
            return SystemInformation.bestEffortValue(for: rawBytes, metadata: metadata)
        }
    }
    
    func invalidateCaches() {
        cachedLabel = nil
        cachedDescription = nil
        cachedMetadata = nil
        cachedRawBytes = nil
    }
}
