//
//  SystemEntryDetailView.swift
//  Canopy
//
//  Created by Leptos on 11/15/25.
//

import SwiftUI

struct SystemEntryDetailView: View {
    let entry: SystemEntry
    
    private var navigationTitle: String {
        switch entry.label {
        case .success(let title):
            return title
        case .failure:
            return "Entry"
        }
    }
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Label") {
                    switch entry.label {
                    case .success(let success):
                        Text(success)
                            .textSelection(.enabled)
                    case .failure(let failure):
                        Text(failure.localizedDescription)
                            .foregroundStyle(Color.red)
                    }
                }
                
                LabeledContent("Description") {
                    switch entry.description {
                    case .success(let success):
                        Text(success)
                    case .failure(let failure):
                        Text(failure.localizedDescription)
                            .foregroundStyle(Color.red)
                    }
                }
                
                LabeledContent("Value") {
                    switch entry.bestEffortValue {
                    case .success(let success):
                        BestEffortValueView(value: success)
                            .textSelection(.enabled)
                        
                    case .failure(let failure):
                        Text(failure.localizedDescription)
                            .foregroundStyle(Color.red)
                    }
                }
            }
            
            Section("Metadata") {
                switch entry.metadata {
                case .success(let success):
                    LabeledContent("Type") {
                        switch success.flags.type {
                        case .node:
                            Text("node")
                        case .int:
                            Text("int")
                        case .string:
                            Text("string")
                        case .quad:
                            Text("quad")
                        case .opaque:
                            Text("opaque")
                        default:
                            Text("unknown")
                                .foregroundStyle(Color.red)
                        }
                    }
                    
                    LabeledContent("Raw type") {
                        Text(success.flags.type.rawValue, format: .number)
                            .monospaced()
                            .textSelection(.enabled)
                    }
                    
                    LabeledContent("Format") {
                        Text(success.format)
                            .monospaced()
                            .textSelection(.enabled)
                    }
                case .failure(let failure):
                    Text(failure.localizedDescription)
                        .foregroundStyle(Color.red)
                }
            }
            
            Section("Flags") {
                switch entry.metadata {
                case .success(let success):
                    ObjectFlagsSection(flags: success.flags)
                    
                case .failure(let failure):
                    Text(failure.localizedDescription)
                        .foregroundStyle(Color.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(navigationTitle)
        .refreshable {
            entry.invalidateCaches()
        }
    }
}

struct ObjectFlagsSection: View {
    let flags: SystemInformation.ObjectFlags
    
    private func breakdownFlags() -> ([(label: String, flag: SystemInformation.ObjectFlags)], SystemInformation.ObjectFlags) {
        var copy = flags
        var options: [(label: String, flag: SystemInformation.ObjectFlags)] = []
        
        func check(_ flag: SystemInformation.ObjectFlags, label: String) {
            guard copy.contains(flag) else { return }
            options.append( (label, flag) )
            copy.remove(flag)
        }
        
        // type mask
        copy.remove(SystemInformation.ObjectFlags(rawValue: CTLTYPE))
        
        check(.read, label: "Read")
        check(.write, label: "Write")
        check(.noLock, label: "No lock")
        check(.anybody, label: "Anybody")
        check(.secure, label: "Secure")
        check(.masked, label: "Masked")
        check(.noAuto, label: "No Auto")
        check(.kern, label: "Kern")
        check(.locked, label: "Locked")
        check(.oidTwo, label: "OID 2")
        check(.permanent, label: "Permanent")
        check(.experiment, label: "Experiment")
        check(.legacyExperiment, label: "Legacy experiment")
        
        return (options, copy)
    }
    
    var body: some View {
        let (knownOptions, remainingFlags) = breakdownFlags()
        
        ForEach(knownOptions, id: \.flag.rawValue) { (label, flag) in
            LabeledContent(label) {
                Text("0x" + String(flag.rawValue, radix: 0x10))
                    .monospaced()
            }
        }
        
        if !remainingFlags.isEmpty {
            LabeledContent {
                Text("0x" + String(remainingFlags.rawValue, radix: 0x10))
                    .monospaced()
            } label: {
                Text("Unknown")
                    .italic()
            }
        }
        
        LabeledContent {
            Text("0x" + String(flags.rawValue, radix: 0x10))
                .monospaced()
        } label: {
            Text("Raw value")
                .bold()
        }
    }
}
