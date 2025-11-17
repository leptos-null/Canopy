//
//  SystemInformation.swift
//  Canopy
//
//  Created by Leptos on 11/15/25.
//

import Foundation
import System

// based on https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl/sysctl.c#L97-L102

let CTL_SYSCTL: CInt = 0
let CTL_SYSCTL_NAME: CInt = 1
let CTL_SYSCTL_NEXT: CInt = 2
let CTL_SYSCTL_NAME2OID: CInt = 3
let CTL_SYSCTL_OIDFMT: CInt = 4
let CTL_SYSCTL_OIDDESCR: CInt = 5

// end reference


enum SystemInformation { // namespace
}

extension SystemInformation {
    struct ObjectID: Hashable {
        let rawValue: [Int32]
    }
    
    struct ObjectType: RawRepresentable, Hashable {
        let rawValue: u_int
        
        init(rawValue: u_int) {
            self.rawValue = rawValue
        }
        
        init(rawValue: CInt) {
            self.rawValue = RawValue(rawValue)
        }
        
        /// name is a node
        static let node: Self = .init(rawValue: CTLTYPE_NODE)
        /// name describes an integer
        static let int: Self = .init(rawValue: CTLTYPE_INT)
        /// name describes a string
        static let string: Self = .init(rawValue: CTLTYPE_STRING)
        /// name describes a 64-bit number
        static let quad: Self = .init(rawValue: CTLTYPE_QUAD)
        /// name describes a structure
        static let opaque: Self = .init(rawValue: CTLTYPE_OPAQUE)
        /// name describes a structure
        static let structure: Self = .init(rawValue: CTLTYPE_STRUCT)
    }
    
    struct ObjectFlags: OptionSet {
        let rawValue: u_int
        
        init(rawValue: u_int) {
            self.rawValue = rawValue
        }
        
        init(rawValue: CInt) {
            self.rawValue = RawValue(rawValue)
        }
        
        static func type(_ type: ObjectType) -> Self {
            self.init(rawValue: type.rawValue & u_int(CTLTYPE))
        }
        
        /// Allow reads of variable
        static let read: Self = .init(rawValue: CTLFLAG_RD)
        /// Allow writes to the variable
        static let write: Self = .init(rawValue: CTLFLAG_WR)
        
        static let readWrite: Self = [.read, .write]
        
        /// Don't Lock
        static let noLock: Self = .init(rawValue: CTLFLAG_NOLOCK)
        /// All users can set this var
        static let anybody: Self = .init(rawValue: CTLFLAG_ANYBODY)
        /// Permit set only if `securelevel<=0`
        static let secure: Self = .init(rawValue: CTLFLAG_SECURE)
        /// deprecated variable, do not display
        static let masked: Self = .init(rawValue: CTLFLAG_MASKED)
        /// do not auto-register
        static let noAuto: Self = .init(rawValue: CTLFLAG_NOAUTO)
        /// valid inside the kernel
        static let kern: Self = .init(rawValue: CTLFLAG_KERN)
        /// node will handle locking itself
        static let locked: Self = .init(rawValue: CTLFLAG_LOCKED)
        /// `struct sysctl_oid` has version info
        static let oidTwo: Self = .init(rawValue: CTLFLAG_OID2)
        /// Allows read/write w/ the trial experiment entitlement
        static let experiment: Self = .init(rawValue: CTLFLAG_EXPERIMENT)
        /// Allows writing w/ the legacy trial experiment entitlement
        static let legacyExperiment: Self = .init(rawValue: CTLFLAG_LEGACY_EXPERIMENT)
        
        var type: ObjectType {
            ObjectType(rawValue: self.rawValue & u_int(CTLTYPE))
        }
    }
}

extension SystemInformation {
    struct QueryResult {
        // The amount of data copied into the buffer
        let byteCount: Int
        // All of the data available was written to the buffer
        let didWriteAll: Bool
    }
    
    @discardableResult
    static func object(for objectID: ObjectID, outputBuffer buffer: UnsafeMutableRawBufferPointer) throws(System.Errno) -> QueryResult {
        var rawID = objectID.rawValue
        let result: QueryResult = try rawID.withUnsafeMutableBufferPointer { objectIDPointer throws(System.Errno) in
            var bufferCount = buffer.count
            let result = sysctl(objectIDPointer.baseAddress, u_int(objectIDPointer.count), buffer.baseAddress, &bufferCount, nil, 0)
            let errnoCopy: System.Errno.RawValue = errno
            
            // happy path
            if result == 0 {
                return .init(byteCount: bufferCount, didWriteAll: true)
            }
            
            guard (errnoCopy == ENOMEM) else {
                throw System.Errno(rawValue: errnoCopy)
            }
            
            return .init(byteCount: bufferCount, didWriteAll: false)
        }
        return result
    }
    
    static func probeObjectSize(for objectID: ObjectID) throws(System.Errno) -> Int {
        var rawID = objectID.rawValue
        let result: Int = try rawID.withUnsafeMutableBufferPointer { objectIDPointer throws(System.Errno) in
            var bufferCount: Int = 0
            let result = sysctl(objectIDPointer.baseAddress, u_int(objectIDPointer.count), nil, &bufferCount, nil, 0)
            let errnoCopy: System.Errno.RawValue = errno
            
            guard (result == 0) else {
                throw System.Errno(rawValue: errnoCopy)
            }
            return bufferCount
        }
        return result
    }
    
    static func object<T>(for objectID: ObjectID, maxCount: Int) throws(System.Errno) -> [T] where T: ExpressibleByIntegerLiteral {
        var array: [T] = .init(repeating: 0, count: maxCount)
        
        let boxed: Result<QueryResult, System.Errno> = array.withUnsafeMutableBytes { bytes in
            Result { () throws(System.Errno) in
                try self.object(for: objectID, outputBuffer: bytes)
            }
        }
        let result = try boxed.get()
        
        let (quotient, remainder) = result.byteCount.quotientAndRemainder(dividingBy: MemoryLayout<T>.size)
        
        var targetCount: Int = quotient
        if (remainder != 0) {
            targetCount += 1 // fault
        }
        
        guard result.didWriteAll else {
            throw System.Errno(rawValue: ENOMEM)
        }
        array.removeLast(array.count - targetCount)
        return array
    }
    
    static func object<T>(for objectID: ObjectID) throws(System.Errno) -> [T] where T: ExpressibleByIntegerLiteral {
        let probe = try self.probeObjectSize(for: objectID)
        
        let (quotient, remainder) = probe.quotientAndRemainder(dividingBy: MemoryLayout<T>.size)
        var targetCount: Int = quotient
        if (remainder != 0) {
            targetCount += 1 // fault
        }
        
        return try self.object(for: objectID, maxCount: targetCount)
    }
}


extension SystemInformation {
    static func flags(for objectID: ObjectID) throws(System.Errno) -> ObjectFlags {
        // based on https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl/sysctl.c#L1133-L1138
        
        let prefix: [Int32] = [
            CTL_SYSCTL,
            CTL_SYSCTL_OIDFMT,
        ]
        
        let queryID: ObjectID = .init(rawValue: prefix + objectID.rawValue)
        var flags: u_int = 0
        try withUnsafeMutableBytes(of: &flags) { bytes throws(System.Errno) -> Void in
            try Self.object(for: queryID, outputBuffer: bytes)
        }
        return ObjectFlags(rawValue: flags)
    }
}

extension SystemInformation {
    struct ObjectMetadata {
        let flags: ObjectFlags
        let format: String
    }
    
    static func metadata(for objectID: ObjectID) throws(System.Errno) -> ObjectMetadata {
        // based on https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl/sysctl.c#L1133-L1138
        
        let prefix: [Int32] = [
            CTL_SYSCTL,
            CTL_SYSCTL_OIDFMT,
        ]
        
        let queryID: ObjectID = .init(rawValue: prefix + objectID.rawValue)
        let value: [UInt8] = try Self.object(for: queryID)
        
        let flagsSize = MemoryLayout<u_int>.size
        let flags: u_int = value.withUnsafeBytes { bytes in
            bytes.load(as: u_int.self)
        }
        let formatBytes = value.dropFirst(flagsSize) // drop the bytes used for `flags`
        
        let format = String(nullTerminatedUTF8: formatBytes)
        return ObjectMetadata(flags: .init(rawValue: flags), format: format)
    }
}

extension SystemInformation {
    static func label(for objectID: ObjectID) throws(System.Errno) -> String {
        // based on https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl/sysctl.c#L1291-L1318
        
        let prefix: [Int32] = [
            CTL_SYSCTL,
            CTL_SYSCTL_NAME,
        ]
        
        let queryID: ObjectID = .init(rawValue: prefix + objectID.rawValue)
        let bytes: [UInt8] = try self.object(for: queryID)
        return String(nullTerminatedUTF8: bytes)
    }
    
    static func description(for objectID: ObjectID) throws(System.Errno) -> String {
        let prefix: [Int32] = [
            CTL_SYSCTL,
            CTL_SYSCTL_OIDDESCR,
        ]
        
        let queryID: ObjectID = .init(rawValue: prefix + objectID.rawValue)
        let bytes: [UInt8] = try self.object(for: queryID)
        return String(nullTerminatedUTF8: bytes)
    }
}

extension SystemInformation {
    static func nextObjectID(after objectID: ObjectID) throws(System.Errno) -> ObjectID? {
        // based on https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl/sysctl.c#L1635-L1659
        
        let prefix: [Int32] = [
            CTL_SYSCTL,
            CTL_SYSCTL_NEXT,
        ]
        
        let queryID: ObjectID = .init(rawValue: prefix + objectID.rawValue)
        
        var rawNext: [Int32]
        do {
            rawNext = try self.object(for: queryID, maxCount: Int(CTL_MAXNAME))
        } catch System.Errno.noSuchFileOrDirectory { // ENOENT
            return nil
        }
        return ObjectID(rawValue: rawNext)
    }
    
    static func allObjectIDs() throws(System.Errno) -> [ObjectID] {
        var latest: ObjectID = Self.firstObjectID
        var objectIDs: [ObjectID] = [latest]
        
        // in my testing, `nextObjectID(after:)` does not include nodes.
        // this code attempts to add nodes into the result.
        while let next = try Self.nextObjectID(after: latest) {
            let firstNewIndex: Int? = next.rawValue.indices.first { index in
                guard latest.rawValue.indices.contains(index) else {
                    return true
                }
                let latestValue = latest.rawValue[index]
                let nextValue = next.rawValue[index]
                return (latestValue != nextValue)
            }
            guard let firstNewIndex else {
                continue // duplicate entry? odd, but shouldn't be an issue
            }
            for index in firstNewIndex..<next.rawValue.count {
                let rawValue: [Int32] = .init(next.rawValue[...index])
                let newID = ObjectID(rawValue: rawValue)
                objectIDs.append(newID)
            }
            
            latest = next
        }
        
        return objectIDs
    }
    
    static var firstObjectID: ObjectID {
        // based on https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl/sysctl.c#L1647
        .init(rawValue: [CTL_KERN])
    }
}

extension SystemInformation.ObjectID: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue.lexicographicallyPrecedes(rhs.rawValue)
    }
}

extension SystemInformation.ObjectFlags {
    // https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/bsd/sys/sysctl.h#L169
    /// permanent sysctl_oid
    static let permanent: Self = .init(rawValue: 0x00200000 as CInt)
}

extension SystemInformation.ObjectMetadata {
    enum TypeHeuristic {
        case string
        
        case signedInteger
        case unsignedInteger
        
        case opaque
    }
    
    var typeHeuristic: TypeHeuristic {
        // a mix of my own testing and
        // https://freebsdfoundation.org/wp-content/uploads/2014/01/Implementing-System-Control-Nodes-sysctl.pdf
        // https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl/sysctl.c#L1177
        
        if (self.flags.type == .string) || self.format == "A" { // ASCII
            return .string
        }
        if self.format.starts(with: "S") { // struct
            return .opaque
        }
        
        let signedNumerics: Set<String> = [
            "I", // integer
            "L", // long
            "Q", // quad
        ]
        
        if signedNumerics.contains(self.format) {
            return .signedInteger
        }
        
        let unsignedNumerics: Set<String> = [
            "U", // unsigned
            
            "UI", // unsigned integer
            "IU", // integer unsigned
            
            "UL", // unsigned long
            "LU", // long unsigned
            
            "UQ", // unsigned quad
            "QU", // quad unsigned
        ]
        
        if unsignedNumerics.contains(self.format) {
            return .unsignedInteger
        }
        
        switch self.flags.type {
        case .int, .quad:
            return .signedInteger
        default:
            return .opaque
        }
    }
}

extension String {
    init<S>(nullTerminatedUTF8 bytes: S) where S: Sequence, S.Element == UTF8.CodeUnit {
        let characters = bytes.prefix { byte in
            byte != 0 // i.e. null terminator
        }
        self.init(decoding: characters, as: UTF8.self)
    }
}
