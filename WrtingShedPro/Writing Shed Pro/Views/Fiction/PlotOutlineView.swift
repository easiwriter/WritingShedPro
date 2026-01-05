//
//  PlotOutlineView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Plot structure with Hero's Journey
//

import SwiftUI
import SwiftData

/// View for managing plot elements and Hero's Journey structure
struct PlotOutlineView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddPlotElement = false
    @State private var selectedPlotElement: PlotElement?
    @State private var showDeleteConfirmation = false
    @State private var elementToDelete: PlotElement?
    
    // MARK: - Computed
    
    private var sortedPlotElements: [PlotElement] {
        (project.plotElements ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    // Group by monomyth stage if project uses monomyth
    private var plotElementsByStage: [(stage: MonomythStage?, elements: [PlotElement])] {
        guard project.useMonomyth else { return [] }
        
        var grouped: [MonomythStage?: [PlotElement]] = [:]
        
        for element in sortedPlotElements {
            let stage = element.monomythStage
            grouped[stage, default: []].append(element)
        }
        
        // Sort: stages in order, then nil (unassigned) last
        var result: [(MonomythStage?, [PlotElement])] = []
        
        for stage in MonomythStage.allCases {
            if let elements = grouped[stage], !elements.isEmpty {
                result.append((stage, elements))
            }
        }
        
        if let unassigned = grouped[nil], !unassigned.isEmpty {
            result.append((nil, unassigned))
        }
        
        return result
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedPlotElements.isEmpty {
                emptyState
            } else if project.useMonomyth {
                monomythList
            } else {
                simpleList
            }
        }
        .navigationTitle(NSLocalizedString("fiction.plot.title", comment: "Plot Outline"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddPlotElement = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("fiction.plot.add", comment: "Add plot element"))
            }
        }
        .sheet(isPresented: $showAddPlotElement) {
            AddPlotElementSheet(project: project)
        }
        .sheet(item: $selectedPlotElement) { element in
            PlotElementDetailView(plotElement: element, project: project)
        }
        .alert(
            NSLocalizedString("fiction.plot.deleteConfirm.title", comment: "Delete plot element?"),
            isPresented: $showDeleteConfirmation,
            presenting: elementToDelete
        ) { element in
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deletePlotElement(element)
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: { element in
            Text(String(format: NSLocalizedString("fiction.plot.deleteConfirm.message", comment: "Delete message"), element.name ?? ""))
        }
    }
    
    // MARK: - Monomyth Grouped List
    
    private var monomythList: some View {
        List {
            ForEach(plotElementsByStage, id: \.stage) { group in
                Section {
                    ForEach(group.elements) { element in
                        PlotElementRowView(element: element, showStage: false)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPlotElement = element
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    elementToDelete = element
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    if let stage = group.stage {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(stage.order + 1).")
                                    .fontWeight(.bold)
                                Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                            }
                            Text(NSLocalizedString("monomyth.\(stage.rawValue).description", comment: "Stage description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(NSLocalizedString("fiction.plot.unassigned", comment: "Unassigned"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Simple List (no monomyth)
    
    private var simpleList: some View {
        List {
            ForEach(sortedPlotElements) { element in
                PlotElementRowView(element: element, showStage: false)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPlotElement = element
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            elementToDelete = element
                            showDeleteConfirmation = true
                        } label: {
                            Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                        }
                    }
            }
            .onMove(perform: movePlotElements)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("fiction.plot.empty.title", comment: "No plot elements"))
                .font(.headline)
            
            Text(project.useMonomyth 
                ? NSLocalizedString("fiction.plot.empty.monomyth.message", comment: "Empty monomyth message")
                : NSLocalizedString("fiction.plot.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddPlotElement = true
            } label: {
                Label(NSLocalizedString("fiction.plot.add", comment: "Add plot element"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deletePlotElement(_ element: PlotElement) {
        modelContext.delete(element)
        try? modelContext.save()
        renumberPlotElements()
    }
    
    private func movePlotElements(from source: IndexSet, to destination: Int) {
        var elements = sortedPlotElements
        elements.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, element) in elements.enumerated() {
            element.userOrder = index
        }
        
        try? modelContext.save()
    }
    
    private func renumberPlotElements() {
        for (index, element) in sortedPlotElements.enumerated() {
            element.userOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Plot Element Row View

struct PlotElementRowView: View {
    let element: PlotElement
    let showStage: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                .font(.headline)
            
            if let notes = element.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Show stage if requested and available
            if showStage, let stage = element.monomythStage {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.3x3")
                        .font(.caption)
                    Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage"))
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 4)
    }
}
