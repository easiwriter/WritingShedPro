//
//  ReviewManager.swift
//  Writing Shed Pro
//
//  Created on 10 December 2025.
//  Manages App Store review requests with smart timing
//

import Foundation
import StoreKit
import SwiftUI

/// Manages App Store review prompts with intelligent timing to avoid annoying users
@MainActor
final class ReviewManager: ObservableObject {
    
    static let shared = ReviewManager()
    
    private init() {}
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let lastReviewRequestDate = "lastReviewRequestDate"
        static let reviewRequestCount = "reviewRequestCount"
        static let firstLaunchDate = "firstLaunchDate"
        static let appLaunchCount = "appLaunchCount"
        static let significantEventCount = "significantEventCount"
    }
    
    // MARK: - Configuration
    
    /// Minimum days between review requests
    private let minimumDaysBetweenRequests: TimeInterval = 120 // ~4 months
    
    /// Minimum days since first launch before requesting review
    private let minimumDaysSinceFirstLaunch: TimeInterval = 7
    
    /// Maximum number of times to automatically request review
    private let maxAutomaticRequests = 3
    
    /// Minimum app launches before requesting review
    private let minimumLaunchCount = 5
    
    /// Minimum significant events before requesting review
    private let minimumSignificantEvents = 10
    
    // MARK: - Public Methods
    
    /// Request review from user (manual request from Settings menu)
    /// This bypasses timing checks and always shows the prompt
    /// Call this from a view with access to the environment
    func requestReviewManually(in environment: EnvironmentValues) {
        #if DEBUG
        print("📱 Review: Manual review requested from Settings")
        #endif
        
        // Record the request
        recordReviewRequest()
        
        // Request review using modern API
        if let requestReview = environment.requestReview {
            requestReview()
        }
    }
    
    /// Request review automatically based on app usage patterns
    /// This respects timing rules and won't show if conditions aren't met
    /// Call this from a view with access to the environment
    func requestReviewIfAppropriate(in environment: EnvironmentValues) {
        guard shouldRequestReview() else {
            #if DEBUG
            print("📱 Review: Conditions not met for automatic review request")
            #endif
            return
        }
        
        #if DEBUG
        print("📱 Review: Conditions met, requesting review")
        #endif
        
        // Record the request
        recordReviewRequest()
        
        // Request review using modern API
        if let requestReview = environment.requestReview {
            requestReview()
        }
    }
    
    /// Record a significant event (creating file, completing import, etc.)
    func recordSignificantEvent() {
        let count = UserDefaults.standard.integer(forKey: Keys.significantEventCount)
        UserDefaults.standard.set(count + 1, forKey: Keys.significantEventCount)
        
        #if DEBUG
        print("📱 Review: Significant event recorded (total: \(count + 1))")
        #endif
    }
    
    /// Record app launch (call this from app startup)
    func recordAppLaunch() {
        // Record first launch date if not set
        if UserDefaults.standard.object(forKey: Keys.firstLaunchDate) == nil {
            UserDefaults.standard.set(Date(), forKey: Keys.firstLaunchDate)
            #if DEBUG
            print("📱 Review: First launch recorded")
            #endif
        }
        
        // Increment launch count
        let count = UserDefaults.standard.integer(forKey: Keys.appLaunchCount)
        UserDefaults.standard.set(count + 1, forKey: Keys.appLaunchCount)
        
        #if DEBUG
        print("📱 Review: App launch recorded (total: \(count + 1))")
        #endif
    }
    
    // MARK: - Public Methods
    
    func shouldRequestReview() -> Bool {
        // Check if we've exceeded maximum automatic requests
        let requestCount = UserDefaults.standard.integer(forKey: Keys.reviewRequestCount)
        guard requestCount < maxAutomaticRequests else {
            #if DEBUG
            print("📱 Review: Max automatic requests reached (\(requestCount))")
            #endif
            return false
        }
        
        // Check minimum time since last request
        if let lastRequestDate = UserDefaults.standard.object(forKey: Keys.lastReviewRequestDate) as? Date {
            let daysSinceLastRequest = Date().timeIntervalSince(lastRequestDate) / 86400
            guard daysSinceLastRequest >= minimumDaysBetweenRequests else {
                #if DEBUG
                print("📱 Review: Too soon since last request (\(Int(daysSinceLastRequest)) days)")
                #endif
                return false
            }
        }
        
        // Check minimum time since first launch
        guard let firstLaunchDate = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date else {
            #if DEBUG
            print("📱 Review: No first launch date recorded")
            #endif
            return false
        }
        
        let daysSinceFirstLaunch = Date().timeIntervalSince(firstLaunchDate) / 86400
        guard daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch else {
            #if DEBUG
            print("📱 Review: Too soon since first launch (\(Int(daysSinceFirstLaunch)) days)")
            #endif
            return false
        }
        
        // Check minimum launch count
        let launchCount = UserDefaults.standard.integer(forKey: Keys.appLaunchCount)
        guard launchCount >= minimumLaunchCount else {
            #if DEBUG
            print("📱 Review: Not enough launches (\(launchCount)/\(minimumLaunchCount))")
            #endif
            return false
        }
        
        // Check minimum significant events
        let eventCount = UserDefaults.standard.integer(forKey: Keys.significantEventCount)
        guard eventCount >= minimumSignificantEvents else {
            #if DEBUG
            print("📱 Review: Not enough significant events (\(eventCount)/\(minimumSignificantEvents))")
            #endif
            return false
        }
        
        #if DEBUG
        print("📱 Review: All conditions met - OK to request review")
        #endif
        return true
    }
    
    func recordReviewRequest() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastReviewRequestDate)
        
        let count = UserDefaults.standard.integer(forKey: Keys.reviewRequestCount)
        UserDefaults.standard.set(count + 1, forKey: Keys.reviewRequestCount)
        
        #if DEBUG
        print("📱 Review: Request recorded (total: \(count + 1))")
        #endif
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    /// Reset all review tracking (debug only)
    func resetReviewTracking() {
        UserDefaults.standard.removeObject(forKey: Keys.lastReviewRequestDate)
        UserDefaults.standard.removeObject(forKey: Keys.reviewRequestCount)
        UserDefaults.standard.removeObject(forKey: Keys.firstLaunchDate)
        UserDefaults.standard.removeObject(forKey: Keys.appLaunchCount)
        UserDefaults.standard.removeObject(forKey: Keys.significantEventCount)
        print("📱 Review: All tracking data reset")
    }
    
    /// Get current review tracking stats (debug only)
    func getReviewStats() -> String {
        let requestCount = UserDefaults.standard.integer(forKey: Keys.reviewRequestCount)
        let launchCount = UserDefaults.standard.integer(forKey: Keys.appLaunchCount)
        let eventCount = UserDefaults.standard.integer(forKey: Keys.significantEventCount)
        let lastRequest = UserDefaults.standard.object(forKey: Keys.lastReviewRequestDate) as? Date
        let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date
        
        var stats = """
        Review Stats:
        - Review requests: \(requestCount)/\(maxAutomaticRequests)
        - App launches: \(launchCount)
        - Significant events: \(eventCount)
        """
        
        if let date = lastRequest {
            let daysSince = Int(Date().timeIntervalSince(date) / 86400)
            stats += "\n- Last request: \(daysSince) days ago"
        } else {
            stats += "\n- Last request: Never"
        }
        
        if let date = firstLaunch {
            let daysSince = Int(Date().timeIntervalSince(date) / 86400)
            stats += "\n- First launch: \(daysSince) days ago"
        } else {
            stats += "\n- First launch: Not recorded"
        }
        
        stats += "\n- Can request: \(shouldRequestReview() ? "YES" : "NO")"
        
        return stats
    }
    #endif
}
