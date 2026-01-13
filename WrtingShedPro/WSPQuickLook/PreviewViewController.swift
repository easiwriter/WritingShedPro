//
//  PreviewViewController.swift
//  WSPQuickLook
//
//  Quick Look Preview Extension for .wsp files
//  Works on iOS and Mac Catalyst
//

import UIKit
import QuickLook

class PreviewViewController: UIViewController, QLPreviewingController {
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let projectNameLabel = UILabel()
    private let projectTypeLabel = UILabel()
    private let statsLabel = UILabel()
    private let dateLabel = UILabel()
    private let brandLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Container stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // App icon - use a distinctive SF Symbol for Writing Shed Pro
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .regular)
        iconImageView.image = UIImage(systemName: "house.fill", withConfiguration: config)
        iconImageView.tintColor = .systemBrown
        stackView.addArrangedSubview(iconImageView)
        
        // Spacer
        let spacer1 = UIView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer1)
        
        // Project name
        projectNameLabel.font = .boldSystemFont(ofSize: 20)
        projectNameLabel.textAlignment = .center
        projectNameLabel.numberOfLines = 2
        projectNameLabel.textColor = .label
        stackView.addArrangedSubview(projectNameLabel)
        
        // Project type
        projectTypeLabel.font = .systemFont(ofSize: 15)
        projectTypeLabel.textAlignment = .center
        projectTypeLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(projectTypeLabel)
        
        // Stats
        statsLabel.font = .systemFont(ofSize: 13)
        statsLabel.textAlignment = .center
        statsLabel.textColor = .tertiaryLabel
        stackView.addArrangedSubview(statsLabel)
        
        // Date
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textAlignment = .center
        dateLabel.textColor = .tertiaryLabel
        stackView.addArrangedSubview(dateLabel)
        
        // Spacer
        let spacer2 = UIView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer2)
        
        // Brand
        brandLabel.text = "Writing Shed Pro Project"
        brandLabel.font = .systemFont(ofSize: 11, weight: .medium)
        brandLabel.textAlignment = .center
        brandLabel.textColor = .quaternaryLabel
        stackView.addArrangedSubview(brandLabel)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            spacer1.heightAnchor.constraint(equalToConstant: 12),
            spacer2.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // Read and parse the .wsp file
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let project = json["project"] as? [String: Any] {
                
                // Extract project info
                let name = project["name"] as? String ?? "Untitled Project"
                let projectType = project["type"] as? String ?? "generalPurpose"
                let folders = json["folders"] as? [[String: Any]] ?? []
                
                // Count files recursively
                let fileCount = countFiles(in: folders)
                let folderCount = folders.count
                
                // Format export date
                var dateString = ""
                if let exportDateStr = json["exportDate"] as? String {
                    let isoFormatter = ISO8601DateFormatter()
                    if let date = isoFormatter.date(from: exportDateStr) {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        dateString = "Exported: \(formatter.string(from: date))"
                    }
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.projectNameLabel.text = name
                    self.projectTypeLabel.text = self.formatProjectType(projectType)
                    self.statsLabel.text = "\(folderCount) folder(s), \(fileCount) file(s)"
                    self.dateLabel.text = dateString
                }
                
                handler(nil)
            } else {
                handler(PreviewError.invalidFormat)
            }
        } catch {
            handler(error)
        }
    }
    
    private func countFiles(in folders: [[String: Any]]) -> Int {
        var count = 0
        for folder in folders {
            if let files = folder["textFiles"] as? [[String: Any]] {
                count += files.count
            }
            if let subfolders = folder["folders"] as? [[String: Any]] {
                count += countFiles(in: subfolders)
            }
        }
        return count
    }
    
    private func formatProjectType(_ type: String) -> String {
        switch type {
        case "prose", "generalPurpose": return "Prose Project"
        case "poetry": return "Poetry Project"
        case "fiction": return "Fiction Project"
        case "drama": return "Drama Project"
        default: return type.capitalized + " Project"
        }
    }
    
    enum PreviewError: Error {
        case invalidFormat
    }
}
