import Foundation

/// Art der Rückmeldung (FR-17.3): eine Idee oder ein Hinweis auf ein Problem.
public enum FeedbackKind: String, CaseIterable, Codable, Sendable { case idea, issue }
