/// AareEdgeSDK - On-device PHI detection and policy verification
///
/// AareEdgeSDK provides tools for detecting Protected Health Information (PHI)
/// in text using CoreML models and verifying compliance with policies using
/// the Z3Lite constraint solver.
///
/// ## Overview
///
/// The SDK consists of three main components:
///
/// 1. **PHIDetector**: Detects HIPAA Safe Harbor PHI categories in text
/// 2. **WordPieceTokenizer**: Tokenizes text for transformer models
/// 3. **Z3Lite**: Lightweight constraint solver for policy verification
///
/// ## Quick Start
///
/// ```swift
/// import AareEdgeSDK
///
/// // Initialize detector with your model and vocabulary
/// let detector = try PHIDetector(
///     modelURL: modelURL,
///     vocabURL: vocabURL
/// )
///
/// // Detect PHI in text
/// let result = try detector.detect("Patient John Smith, DOB: 01/15/1980")
///
/// // Check results
/// if result.containsPHI {
///     for entity in result.entities {
///         print("\(entity.type): \(entity.text)")
///     }
/// }
/// ```
///
/// ## PHI Categories
///
/// The SDK detects the 18 HIPAA Safe Harbor PHI categories:
///
/// - NAME: Patient and provider names
/// - LOCATION: Addresses, cities, zip codes
/// - DATE: Dates of birth, admission, discharge
/// - PHONE: Telephone numbers
/// - FAX: Fax numbers
/// - EMAIL: Email addresses
/// - SSN: Social Security numbers
/// - MRN: Medical record numbers
/// - HEALTH_PLAN: Health plan beneficiary numbers
/// - ACCOUNT: Account numbers
/// - LICENSE: Certificate/license numbers
/// - VEHICLE: Vehicle identifiers
/// - DEVICE: Device identifiers
/// - URL: Web URLs
/// - IP: IP addresses
/// - BIOMETRIC: Biometric identifiers
/// - PHOTO: Full face photos
/// - OTHER: Other unique identifiers
///
/// ## Policy Verification
///
/// Use Z3Lite to verify compliance rules:
///
/// ```swift
/// let solver = Z3Lite()
///
/// // Define policy: PHI count must be 0 for public release
/// let phiCount = solver.intVar("phi_count")
/// solver.assert(phiCount.eq(0))
///
/// // Bind actual value and check
/// solver.bind("phi_count", to: .int(result.entities.count))
/// let check = solver.check()
///
/// if check.isUnsatisfiable {
///     print("Policy violated: PHI detected")
/// }
/// ```

// Re-export main types
@_exported import Foundation

/// SDK version
public let AareEdgeSDKVersion = "1.0.0"

/// SDK build info
public struct AareEdgeSDKInfo {
    public static let version = AareEdgeSDKVersion
    public static let name = "AareEdgeSDK"
    public static let description = "On-device PHI detection and policy verification"

    private init() {}
}
