//
//  PlotOutlineView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Plot structure with Hero's Journey
//

import SwiftUI
import SwiftData
import TipKit

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
    
    // Group by stage based on story structure
    private var plotElementsByStage: [(stageOrder: Int?, stageName: String?, elements: [PlotElement])] {
        guard project.storyStructure != .freeform else { return [] }
        
        var grouped: [Int?: [PlotElement]] = [:]
        
        for element in sortedPlotElements {
            let stageOrder = element.stageOrder
            grouped[stageOrder, default: []].append(element)
        }
        
        // Sort: stages in order, then nil (unassigned) last
        var result: [(Int?, String?, [PlotElement])] = []
        
        switch project.storyStructure {
        case .monomythVogler:
            for stage in MonomythStage.allCases {
                if let elements = grouped[stage.order], !elements.isEmpty {
                    result.append((stage.order, stage.localizedName, elements))
                }
            }
        case .monomythCampbell:
            for stage in CampbellMonomythStage.allCases {
                if let elements = grouped[stage.order], !elements.isEmpty {
                    result.append((stage.order, stage.localizedName, elements))
                }
            }
        case .threeAct:
            for stage in ThreeActStage.allCases {
                if let elements = grouped[stage.order], !elements.isEmpty {
                    result.append((stage.order, stage.localizedName, elements))
                }
            }
        case .freeform:
            break
        }
        
        if let unassigned = grouped[nil], !unassigned.isEmpty {
            result.append((nil, nil, unassigned))
        }
        
        return result
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedPlotElements.isEmpty {
                emptyState
            } else if project.storyStructure != .freeform {
                structuredList
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
    
    // MARK: - Structured List (grouped by stage)
    
    private var structuredList: some View {
        List {
            ForEach(plotElementsByStage, id: \.stageOrder) { group in
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
                    if let stageOrder = group.stageOrder, let stageName = group.stageName {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(stageOrder).")
                                    .fontWeight(.bold)
                                Text(stageName)
                            }
                        }
                    } else {
                        Text(NSLocalizedString("fiction.plot.unassigned", comment: "Unassigned"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Simple List (freeform)
    
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
                    // Enable drag-to-reorder without edit mode
                    .onDrag {
                        return NSItemProvider(object: element.id.uuidString as NSString)
                    }
            }
            .onMove(perform: movePlotElements)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            // FR-5.2: Plot Elements tip
            TipView(PlotElementsTip()) { action in
                TipActionHandler.handle(action, guideSection: PlotElementsTip.guideSection, modelContext: modelContext)
            }
            .padding(.horizontal)
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("fiction.plot.empty.title", comment: "No plot elements"))
                .font(.headline)
            
            Text(project.storyStructure.usesMonomyth 
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
        VStack(alignment: .leading, spacing: 3) {
            Text(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                .font(.body)
                .fontWeight(.semibold)
            
            if let notes = element.notes, !notes.isEmpty {
                Text(notes)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Show stage if requested and available
            if showStage, let stage = element.monomythStage {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.3x3")
                        .font(.footnote)
                    Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage"))
                        .font(.footnote)
                }
                .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
