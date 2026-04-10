import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class WriteCoalescerTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        // Use a minimal in-memory container for coalescer tests.
        // We only need the context — no specific models are required.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Schema([]), configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - T007(a): Single requestSave produces one save

    func testSingleRequestSaveProducesOneSave() async {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 0.1)

        coalescer.requestSave()

        // Wait for the timer to fire
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(coalescer.saveCount, 1)
        XCTAssertEqual(coalescer.requestCount, 1)
        XCTAssertFalse(coalescer.pendingSave)
    }

    // MARK: - T007(b): Rapid requests coalesce into one save

    func testRapidRequestsCoalesceIntoOneSave() async {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 0.2)

        for _ in 0..<10 {
            coalescer.requestSave()
        }

        // Wait for the single coalesced flush
        try? await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(coalescer.saveCount, 1, "10 rapid requests should produce exactly 1 save")
        XCTAssertEqual(coalescer.requestCount, 10)
    }

    // MARK: - T007(c): flush() immediately saves when pending

    func testFlushImmediatelySavesWhenPending() {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 10.0)

        coalescer.requestSave()
        XCTAssertTrue(coalescer.pendingSave)

        coalescer.flush()

        XCTAssertEqual(coalescer.saveCount, 1)
        XCTAssertFalse(coalescer.pendingSave)
        XCTAssertNotNil(coalescer.lastFlushTime)
    }

    // MARK: - T007(d): flush() is no-op when not pending

    func testFlushIsNoOpWhenNotPending() {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 2.0)

        coalescer.flush()

        XCTAssertEqual(coalescer.saveCount, 0)
        XCTAssertNil(coalescer.lastFlushTime)
    }

    // MARK: - T007(e): requestSave after flush starts new timer

    func testRequestSaveAfterFlushStartsNewTimer() async {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 0.1)

        coalescer.requestSave()
        coalescer.flush()
        XCTAssertEqual(coalescer.saveCount, 1)

        coalescer.requestSave()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(coalescer.saveCount, 2)
        XCTAssertEqual(coalescer.requestCount, 2)
    }

    // MARK: - cancelPending

    func testCancelPendingPreventsFlush() async {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 0.1)

        coalescer.requestSave()
        coalescer.cancelPending()

        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(coalescer.saveCount, 0)
        XCTAssertFalse(coalescer.pendingSave)
    }

    // MARK: - T019: Integration — coalescing across simulated operations

    func testMultipleOperationsCoalesce() async {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 0.2)

        // Simulate 10 rapid operations from different subsystems
        // (comment + footnote + formatting interleaved)
        for _ in 0..<10 {
            coalescer.requestSave()
        }

        // Wait for the single coalesced flush
        try? await Task.sleep(for: .milliseconds(400))

        // All 10 requests should produce at most 1 save (50%+ reduction)
        XCTAssertLessThanOrEqual(coalescer.saveCount, 3,
            "10 rapid requests should produce ≤3 saves (validates SC-001 50% reduction)")
        XCTAssertEqual(coalescer.requestCount, 10)
    }

    // MARK: - T030: Stress test — 200 rapid requests

    func testStressCoalescingAtScale() async {
        let coalescer = WriteCoalescer(modelContext: context, flushDelay: 0.3)

        // Simulate 200 rapid requestSave() calls over ~1 second
        for i in 0..<200 {
            coalescer.requestSave()
            // Small random-ish delay to simulate realistic editing bursts
            if i % 20 == 0 {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        // Final flush
        coalescer.flush()

        // Wait for everything to settle
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(coalescer.requestCount, 200)
        XCTAssertLessThanOrEqual(coalescer.saveCount, 30,
            "200 requests should produce ≤30 saves (coalescing at scale)")
        XCTAssertFalse(coalescer.pendingSave, "No pending saves after flush")
    }
}
