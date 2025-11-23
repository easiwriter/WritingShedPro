//
//  ImageHandleOverlay.swift
//  Writing Shed Pro
//
//  Displays resize handles around a selected image
//  Handles respect alignment: center-aligned keeps center fixed,
//  left-aligned keeps left edge fixed, right-aligned keeps right edge fixed
//

import SwiftUI

struct ImageHandleOverlay: View {
    let imageFrame: CGRect
    let alignment: ImageAttachment.ImageAlignment
    let onResize: (CGSize, CGPoint) -> Void
    
    @State private var isDragging = false
    @State private var hoveredHandle: HandlePosition?
    @State private var dragStartSize: CGSize = .zero
    
    private let handleSize: CGFloat = 10
    private let handleColor = Color.blue
    private let handleBorderColor = Color.white
    
    enum HandlePosition {
        case topLeft, topCenter, topRight
        case middleLeft, middleRight
        case bottomLeft, bottomCenter, bottomRight
    }
    
    var body: some View {
        ZStack {
            // Corner handles
            handleView(at: .topLeft, x: 0, y: 0)
            handleView(at: .topRight, x: imageFrame.width - handleSize, y: 0)
            handleView(at: .bottomLeft, x: 0, y: imageFrame.height - handleSize)
            handleView(at: .bottomRight, x: imageFrame.width - handleSize, y: imageFrame.height - handleSize)
            
            // Edge handles
            handleView(at: .topCenter, x: (imageFrame.width - handleSize) / 2, y: 0)
            handleView(at: .bottomCenter, x: (imageFrame.width - handleSize) / 2, y: imageFrame.height - handleSize)
            handleView(at: .middleLeft, x: 0, y: (imageFrame.height - handleSize) / 2)
            handleView(at: .middleRight, x: imageFrame.width - handleSize, y: (imageFrame.height - handleSize) / 2)
        }
        .frame(width: imageFrame.width, height: imageFrame.height)
    }
    
    private func handleView(at position: HandlePosition, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(handleColor)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .strokeBorder(handleBorderColor, lineWidth: 1)
            )
            .scaleEffect(hoveredHandle == position ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: hoveredHandle)
            .position(x: x + handleSize / 2, y: y + handleSize / 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            // Capture starting size on first drag event
                            dragStartSize = imageFrame.size
                            isDragging = true
                        }
                        // Update preview if needed (for now, just track state)
                    }
                    .onEnded { value in
                        // Calculate final size based on total translation from start
                        handleDragEnd(position: position, translation: value.translation)
                        isDragging = false
                    }
            )
            .onHover { isHovered in
                hoveredHandle = isHovered ? position : nil
            }
    }
    
    private func handleDragEnd(position: HandlePosition, translation: CGSize) {
        
        // Calculate new size based on handle position and translation FROM STARTING SIZE
        var newSize = dragStartSize
        var anchor = CGPoint.zero
        
        // Determine anchor point based on alignment
        switch alignment {
        case .center, .inline:
            // Keep center fixed - anchor at center
            anchor = CGPoint(x: dragStartSize.width / 2, y: dragStartSize.height / 2)
            
            // For center-aligned, resize from center
            switch position {
            case .topLeft:
                let delta = max(translation.width, translation.height)
                newSize.width = dragStartSize.width - delta * 2
                newSize.height = dragStartSize.height - delta * 2
            case .topRight:
                let delta = max(-translation.width, translation.height)
                newSize.width = dragStartSize.width + delta * 2
                newSize.height = dragStartSize.height + delta * 2
            case .bottomLeft:
                let delta = max(translation.width, -translation.height)
                newSize.width = dragStartSize.width - delta * 2
                newSize.height = dragStartSize.height - delta * 2
            case .bottomRight:
                let delta = max(-translation.width, -translation.height)
                newSize.width = dragStartSize.width + delta * 2
                newSize.height = dragStartSize.height + delta * 2
            case .topCenter:
                newSize.height = dragStartSize.height - translation.height * 2
                newSize.width = newSize.height * (dragStartSize.width / dragStartSize.height)
            case .bottomCenter:
                newSize.height = dragStartSize.height + translation.height * 2
                newSize.width = newSize.height * (dragStartSize.width / dragStartSize.height)
            case .middleLeft:
                newSize.width = dragStartSize.width - translation.width * 2
                newSize.height = newSize.width * (dragStartSize.height / dragStartSize.width)
            case .middleRight:
                newSize.width = dragStartSize.width + translation.width * 2
                newSize.height = newSize.width * (dragStartSize.height / dragStartSize.width)
            }
            
        case .left:
            // Keep left edge fixed - anchor at left
            anchor = CGPoint(x: 0, y: dragStartSize.height / 2)
            
            // Resize from right side
            switch position {
            case .topRight, .middleRight, .bottomRight:
                newSize.width = dragStartSize.width + translation.width
                newSize.height = newSize.width * (dragStartSize.height / dragStartSize.width)
            case .topCenter, .bottomCenter:
                // For top/bottom, still resize maintaining aspect ratio
                let widthChange = translation.height * (dragStartSize.width / dragStartSize.height)
                newSize.width = dragStartSize.width + widthChange
                newSize.height = dragStartSize.height + translation.height
            default:
                // Left handles don't resize when left-aligned
                return
            }
            
        case .right:
            // Keep right edge fixed - anchor at right
            anchor = CGPoint(x: dragStartSize.width, y: dragStartSize.height / 2)
            
            // Resize from left side
            switch position {
            case .topLeft, .middleLeft, .bottomLeft:
                newSize.width = dragStartSize.width - translation.width
                newSize.height = newSize.width * (dragStartSize.height / dragStartSize.width)
            case .topCenter, .bottomCenter:
                // For top/bottom, still resize maintaining aspect ratio
                let widthChange = translation.height * (dragStartSize.width / dragStartSize.height)
                newSize.width = dragStartSize.width - widthChange
                newSize.height = dragStartSize.height + translation.height
            default:
                // Right handles don't resize when right-aligned
                return
            }
        }
        
        // Maintain minimum size
        newSize.width = max(50, newSize.width)
        newSize.height = max(50, newSize.height)
        
        // Maintain aspect ratio
        let aspectRatio = dragStartSize.width / dragStartSize.height
        newSize.height = newSize.width / aspectRatio
        
        onResize(newSize, anchor)
    }
}

#Preview {
    VStack {
        Text("imageHandle.preview.title")
            .font(.title)
        
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 300, height: 200)
            
            ImageHandleOverlay(
                imageFrame: CGRect(x: 0, y: 0, width: 300, height: 200),
                alignment: .center,
                onResize: { size, anchor in
                    print("New size: \(size), anchor: \(anchor)")
                }
            )
        }
        
        Text("imageHandle.preview.hint")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
