//
//  PublicationRowView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 2: Publications Management UI
//

import SwiftUI

struct PublicationRowView: View {
    let publication: Publication
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Text(publication.type?.icon ?? "📄")
                .font(.title2)
                .accessibilityHidden(true) // Announced in label
            
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(publication.name)
                    .font(.headline)
                
                // Deadline status
                if publication.hasDeadline {
                    deadlineView
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(Text(NSLocalizedString("accessibility.publication.tap.hint", comment: "Tap to view hint")))
    }
    
    private var deadlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: deadlineIcon)
                .font(.caption)
            
            Text(deadlineText)
                .font(.caption)
        }
        .foregroundStyle(deadlineColor)
    }
    
    private var deadlineIcon: String {
        switch publication.deadlineStatus {
        case .passed: return "exclamationmark.triangle.fill"
        case .approaching: return "clock.fill"
        case .future: return "calendar"
        case .none: return ""
        }
    }
    
    private var deadlineText: String {
        guard let days = publication.daysUntilDeadline else {
            return NSLocalizedString("publications.deadline.none", comment: "No deadline")
        }
        
        if publication.isDeadlinePassed {
            return NSLocalizedString("publications.deadline.passed", comment: "Deadline passed")
        }
        
        return String(
            format: NSLocalizedString("publications.deadline.approaching", comment: "Days left format"),
            days
        )
    }
    
    private var deadlineColor: Color {
        switch publication.deadlineStatus {
        case .passed: return .red
        case .approaching: return .orange
        case .future: return .secondary
        case .none: return .secondary
        }
    }
    
    private var accessibilityLabel: Text {
        var label = Text(
            String(format: NSLocalizedString("accessibility.publication.row", comment: "Publication row"), publication.name)
        )
        
        if let type = publication.type {
            label = label + Text(", ") + Text(
                String(format: NSLocalizedString("accessibility.publication.type", comment: "Type label"), type.displayName)
            )
        }
        
        if publication.isDeadlinePassed {
            label = label + Text(", ") + Text(NSLocalizedString("accessibility.publication.deadline.passed", comment: "Deadline passed"))
        } else if publication.isDeadlineApproaching, let days = publication.daysUntilDeadline {
            label = label + Text(", ") + Text(
                String(format: NSLocalizedString("accessibility.publication.deadline.approaching", comment: "Deadline approaching"), days)
            )
        }
        
        return label
    }
}

#Preview("Magazine with approaching deadline") {
    let publication = Publication(
        name: "Test Magazine",
        type: .magazine,
        deadline: Calendar.current.date(byAdding: .day, value: 5, to: Date())
    )
    return List {
        PublicationRowView(publication: publication)
    }
}

#Preview("Competition with past deadline") {
    let publication = Publication(
        name: "Writing Competition",
        type: .competition,
        deadline: Calendar.current.date(byAdding: .day, value: -5, to: Date())
    )
    return List {
        PublicationRowView(publication: publication)
    }
}

#Preview("Magazine no deadline") {
    let publication = Publication(
        name: "Open Submissions",
        type: .magazine
    )
    return List {
        PublicationRowView(publication: publication)
    }
}
