//
//  ContentView.swift
//  Canopy
//
//  Created by Leptos on 11/15/25.
//

import SwiftUI
import System

struct ContentView: View {
    enum Selection: Hashable {
        case entry(SystemEntry)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .entry(let systemEntry):
                hasher.combine("entry")
                hasher.combine(systemEntry.id)
            }
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.entry(let lhsEntry), .entry(let rhsEntry)):
                return lhsEntry.id == rhsEntry.id
            }
        }
    }
    
    @State private var entriesResult: Result<[SystemEntry], System.Errno>?
    
    private func refresh() {
        self.entriesResult = .init { () throws(System.Errno) in
            try SystemInformation
                .allObjectIDs()
                .map { objectID in
                    SystemEntry(objectID: objectID)
                }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch entriesResult {
                case .success(let entries):
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(value: Selection.entry(entry)) {
                                SystemEntryRow(entry: entry)
                            }
                        }
                    }
                case .failure(let failure):
                    Text(failure.localizedDescription)
                        .foregroundStyle(Color.red)
                        .scenePadding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .none:
                    ProgressView()
                        .scenePadding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Canopy")
            .navigationDestination(for: Selection.self) { selection in
                switch selection {
                case .entry(let entry):
                    SystemEntryDetailView(entry: entry)
                }
            }
            .onAppear {
                guard (entriesResult == nil) else { return }
                self.refresh()
            }
            .refreshable {
                self.refresh()
            }
        }
    }
}

private struct SystemEntryRow: View {
    let entry: SystemEntry
    
    var body: some View {
        LabeledContent {
            switch entry.bestEffortValue {
            case .success(let success):
                BestEffortValueView(value: success)
                
            case .failure(.noSuchFileOrDirectory): // ENOENT
                Text("No entry")
                    .foregroundStyle(.secondary)
                
            case .failure(let failure):
                Text(failure.localizedDescription)
                    .foregroundStyle(Color.red)
            }
        } label: {
            switch entry.label {
            case .success(let success):
                Text(success)
                    .monospaced()
                    .textSelection(.enabled)
            case .failure(let failure):
                Text(failure.localizedDescription)
                    .foregroundStyle(Color.red)
            }
            
            switch entry.description {
            case .success(let success):
                Text(success)
                
            case .failure(.noSuchFileOrDirectory): // ENOENT
                EmptyView() // blank
                
            case .failure(let failure):
                Text(failure.localizedDescription)
                    .foregroundStyle(Color.red)
            }
        }
    }
}

#Preview {
    ContentView()
}
