import Testing
@testable import FrontstageCore

@Suite("Feedback Retry Policy") struct FeedbackRetryPolicyTests {
  @Test("Netz und 5xx wiederholen, 4xx nicht")
  func retryRules() {
    let retry: [Int?] = [nil, 500, 503, 599]
    for code in retry { #expect(FeedbackRetryPolicy.shouldRetry(statusCode: code)) }
    let noRetry: [Int?] = [200, 201, 401, 413, 415, 422, 429]
    for code in noRetry { #expect(!FeedbackRetryPolicy.shouldRetry(statusCode: code)) }
    #expect(FeedbackRetryPolicy.maxAttempts == 3)
    #expect(FeedbackRetryPolicy.delays == [1, 4])
  }
}
