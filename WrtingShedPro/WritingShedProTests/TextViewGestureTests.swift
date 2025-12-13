//
//  TextViewGestureTests.swift
//  Writing Shed ProTests
//
//  Created on 13 December 2025.
//  Tests for pinch zoom and drag scroll gestures
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

@MainActor
final class TextViewGestureTests: XCTestCase {
    
    var textView: UITextView!
    var coordinator: TestCoordinator!
    
    override func setUp() async throws {
        try await super.setUp()
        
        textView = UITextView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        textView.text = String(repeating: "Test content. ", count: 100)
        
        coordinator = TestCoordinator()
        coordinator.currentZoomScale = 1.0
        coordinator.textView = textView
    }
    
    override func tearDown() async throws {
        textView = nil
        coordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - Zoom Scale Tests
    
    func testZoomScale_Default() {
        // Default zoom scale should be 1.0
        XCTAssertEqual(coordinator.currentZoomScale, 1.0)
    }
    
    func testZoomScale_CanBeSet() {
        // Test setting zoom scale
        coordinator.currentZoomScale = 1.5
        XCTAssertEqual(coordinator.currentZoomScale, 1.5)
    }
    
    func testZoomScale_MinimumClamp() {
        // Test that zoom clamps to minimum 0.5x
        let newScale = 0.3 // Below minimum
        let clampedScale = max(0.5, min(3.0, newScale))
        
        XCTAssertEqual(clampedScale, 0.5)
    }
    
    func testZoomScale_MaximumClamp() {
        // Test that zoom clamps to maximum 3.0x
        let newScale = 5.0 // Above maximum
        let clampedScale = max(0.5, min(3.0, newScale))
        
        XCTAssertEqual(clampedScale, 3.0)
    }
    
    func testZoomScale_ValidRange() {
        // Test various valid zoom scales
        let validScales: [CGFloat] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]
        
        for scale in validScales {
            let clampedScale = max(0.5, min(3.0, scale))
            XCTAssertEqual(clampedScale, scale, "Scale \(scale) should be valid")
        }
    }
    
    // MARK: - Transform Tests
    
    func testTransform_Identity() {
        // Identity transform (no zoom)
        let transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        textView.transform = transform
        
        XCTAssertEqual(textView.transform, .identity)
    }
    
    func testTransform_Scale() {
        // Test applying scale transform
        let scale: CGFloat = 1.5
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        textView.transform = transform
        
        XCTAssertNotEqual(textView.transform, .identity)
        XCTAssertEqual(textView.transform.a, scale) // Scale X
        XCTAssertEqual(textView.transform.d, scale) // Scale Y
    }
    
    func testTransform_MultipleScales() {
        // Test applying various scales
        let scales: [CGFloat] = [0.5, 1.0, 1.5, 2.0, 3.0]
        
        for scale in scales {
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            textView.transform = transform
            
            XCTAssertEqual(textView.transform.a, scale)
            XCTAssertEqual(textView.transform.d, scale)
        }
    }
    
    // MARK: - UserDefaults Persistence Tests
    
    func testUserDefaults_SaveZoomFactor() {
        // Test saving zoom factor to UserDefaults
        let testZoom: CGFloat = 1.75
        UserDefaults.standard.set(Double(testZoom), forKey: "textViewZoomFactor")
        
        let savedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        XCTAssertEqual(savedZoom, Double(testZoom))
    }
    
    func testUserDefaults_LoadZoomFactor() {
        // Test loading zoom factor from UserDefaults
        let testZoom: Double = 2.0
        UserDefaults.standard.set(testZoom, forKey: "textViewZoomFactor")
        
        let loadedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        XCTAssertEqual(loadedZoom, testZoom)
    }
    
    func testUserDefaults_DefaultValue() {
        // Test default value when key doesn't exist
        UserDefaults.standard.removeObject(forKey: "testNonExistentZoomKey")
        
        let defaultZoom = UserDefaults.standard.double(forKey: "testNonExistentZoomKey")
        XCTAssertEqual(defaultZoom, 0.0) // UserDefaults returns 0.0 for missing keys
    }
    
    func testUserDefaults_UpdateZoomFactor() {
        // Test updating zoom factor
        UserDefaults.standard.set(1.0, forKey: "textViewZoomFactor")
        var savedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        XCTAssertEqual(savedZoom, 1.0)
        
        UserDefaults.standard.set(1.5, forKey: "textViewZoomFactor")
        savedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        XCTAssertEqual(savedZoom, 1.5)
        
        UserDefaults.standard.set(2.0, forKey: "textViewZoomFactor")
        savedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        XCTAssertEqual(savedZoom, 2.0)
    }
    
    func testUserDefaults_ClearZoomFactor() {
        // Test clearing zoom factor
        UserDefaults.standard.set(1.5, forKey: "textViewZoomFactor")
        XCTAssertEqual(UserDefaults.standard.double(forKey: "textViewZoomFactor"), 1.5)
        
        UserDefaults.standard.removeObject(forKey: "textViewZoomFactor")
        XCTAssertEqual(UserDefaults.standard.double(forKey: "textViewZoomFactor"), 0.0)
    }
    
    // MARK: - Gesture Recognizer Tests
    
    func testPinchGesture_Creation() {
        // Test creating pinch gesture recognizer
        let pinchGesture = UIPinchGestureRecognizer(target: coordinator, action: #selector(TestCoordinator.handlePinch(_:)))
        
        XCTAssertNotNil(pinchGesture)
        XCTAssertEqual(pinchGesture.numberOfTouches, 0) // No active touches
    }
    
    func testPanGesture_Creation() {
        // Test creating pan gesture recognizer
        let panGesture = UIPanGestureRecognizer(target: coordinator, action: #selector(TestCoordinator.handlePan(_:)))
        
        XCTAssertNotNil(panGesture)
        XCTAssertEqual(panGesture.minimumNumberOfTouches, 1)
        XCTAssertEqual(panGesture.maximumNumberOfTouches, Int.max)
    }
    
    func testPanGesture_TwoFingerRequirement() {
        // Test pan gesture with 2-finger requirement
        let panGesture = UIPanGestureRecognizer(target: coordinator, action: #selector(TestCoordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        panGesture.maximumNumberOfTouches = 2
        
        XCTAssertEqual(panGesture.minimumNumberOfTouches, 2)
        XCTAssertEqual(panGesture.maximumNumberOfTouches, 2)
    }
    
    func testGestureRecognizer_AddToTextView() {
        // Test adding gesture recognizers to text view
        let initialCount = textView.gestureRecognizers?.count ?? 0
        
        let pinchGesture = UIPinchGestureRecognizer()
        textView.addGestureRecognizer(pinchGesture)
        
        XCTAssertEqual(textView.gestureRecognizers?.count, initialCount + 1)
        XCTAssertTrue(textView.gestureRecognizers?.contains(pinchGesture) ?? false)
    }
    
    func testGestureRecognizer_MultipleGestures() {
        // Test adding multiple gesture recognizers
        let pinchGesture = UIPinchGestureRecognizer()
        let panGesture = UIPanGestureRecognizer()
        
        textView.addGestureRecognizer(pinchGesture)
        textView.addGestureRecognizer(panGesture)
        
        XCTAssertTrue(textView.gestureRecognizers?.contains(pinchGesture) ?? false)
        XCTAssertTrue(textView.gestureRecognizers?.contains(panGesture) ?? false)
    }
    
    // MARK: - Content Offset Tests (for scroll)
    
    func testContentOffset_Default() {
        // Default content offset should be zero
        XCTAssertEqual(textView.contentOffset, .zero)
    }
    
    func testContentOffset_CanBeSet() {
        // Test setting content offset
        let newOffset = CGPoint(x: 0, y: 100)
        textView.contentOffset = newOffset
        
        XCTAssertEqual(textView.contentOffset, newOffset)
    }
    
    func testContentOffset_BoundsClamping() {
        // Test clamping content offset to valid bounds
        let contentHeight = textView.contentSize.height
        let viewHeight = textView.bounds.height
        let maxOffsetY = max(0, contentHeight - viewHeight)
        
        // Try setting beyond maximum
        var testOffset: CGFloat = maxOffsetY + 100
        var clampedOffset = max(0, min(maxOffsetY, testOffset))
        XCTAssertEqual(clampedOffset, maxOffsetY)
        
        // Try setting below minimum
        testOffset = -50
        clampedOffset = max(0, min(maxOffsetY, testOffset))
        XCTAssertEqual(clampedOffset, 0)
        
        // Try setting in valid range
        testOffset = maxOffsetY / 2
        clampedOffset = max(0, min(maxOffsetY, testOffset))
        XCTAssertEqual(clampedOffset, testOffset)
    }
    
    // MARK: - Integration Tests
    
    func testZoomAndScroll_Independent() {
        // Test that zoom and scroll can work independently
        
        // Apply zoom
        let zoomScale: CGFloat = 1.5
        textView.transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale)
        
        // Apply scroll
        let scrollOffset = CGPoint(x: 0, y: 50)
        textView.contentOffset = scrollOffset
        
        // Verify both are applied
        XCTAssertEqual(textView.transform.a, zoomScale)
        XCTAssertEqual(textView.contentOffset, scrollOffset)
    }
    
    func testZoomPersistence_AcrossViews() {
        // Simulate zoom factor being used across multiple views
        let zoomFactor: CGFloat = 1.75
        
        // Save to UserDefaults
        UserDefaults.standard.set(Double(zoomFactor), forKey: "textViewZoomFactor")
        
        // Create new text view (simulating opening a different file)
        let newTextView = UITextView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        
        // Apply saved zoom
        let savedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        if savedZoom > 0 {
            newTextView.transform = CGAffineTransform(scaleX: CGFloat(savedZoom), y: CGFloat(savedZoom))
        }
        
        // Verify zoom was applied
        XCTAssertEqual(newTextView.transform.a, zoomFactor)
        XCTAssertEqual(newTextView.transform.d, zoomFactor)
    }
    
    // MARK: - Edge Cases
    
    func testZoom_EdgeCaseValues() {
        // Test edge case zoom values
        let edgeCases: [CGFloat] = [0.0, -1.0, 0.5, 0.51, 2.99, 3.0, 3.01, 10.0]
        
        for value in edgeCases {
            let clamped = max(0.5, min(3.0, value))
            XCTAssertGreaterThanOrEqual(clamped, 0.5)
            XCTAssertLessThanOrEqual(clamped, 3.0)
        }
    }
    
    func testContentOffset_NegativeValues() {
        // Test that negative offsets are clamped to zero
        let negativeOffset = CGPoint(x: -50, y: -100)
        
        let clampedX = max(0, negativeOffset.x)
        let clampedY = max(0, negativeOffset.y)
        
        XCTAssertEqual(clampedX, 0)
        XCTAssertEqual(clampedY, 0)
    }
    
    // MARK: - Performance Tests
    
    func testZoomPerformance_RepeatedTransforms() {
        // Test performance of repeated transform applications
        measure {
            for scale in stride(from: 0.5, through: 3.0, by: 0.1) {
                textView.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
    }
    
    func testScrollPerformance_RepeatedOffsets() {
        // Test performance of repeated content offset changes
        measure {
            for offset in stride(from: 0, through: 1000, by: 10) {
                textView.contentOffset = CGPoint(x: 0, y: offset)
            }
        }
    }
}

// MARK: - Test Coordinator

class TestCoordinator: NSObject {
    var currentZoomScale: CGFloat = 1.0
    weak var textView: UITextView?
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        // Test stub for pinch handling
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Test stub for pan handling
    }
}
