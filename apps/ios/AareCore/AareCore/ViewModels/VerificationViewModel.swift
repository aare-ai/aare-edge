// VerificationViewModel - Main view model for the app

import SwiftUI
import Combine

// Note: In actual app, import AareEdge SDK
// import AareEdge

// MARK: - Verification Mode

enum VerificationMode: String, CaseIterable {
    case edge = "edge"
    case cloud = "cloud"

    var title: String {
        switch self {
        case .edge: return "Edge"
        case .cloud: return "Cloud"
        }
    }

    var icon: String {
        switch self {
        case .edge: return "iphone"
        case .cloud: return "cloud"
        }
    }
}

// MARK: - View Model

@MainActor
class VerificationViewModel: ObservableObject {
    // Input
    @Published var inputText: String = ""
    @Published var mode: VerificationMode = .edge

    // State
    @Published var isVerifying: Bool = false
    @Published var isModelLoaded: Bool = false
    @Published var result: VerificationResult?
    @Published var error: Error?

    // Services
    private let verificationService = VerificationService()

    var hasResult: Bool {
        result != nil
    }

    // MARK: - Actions

    func verify() async {
        guard !inputText.isEmpty else { return }

        isVerifying = true
        error = nil

        do {
            switch mode {
            case .edge:
                result = try await verificationService.verifyEdge(text: inputText)
            case .cloud:
                result = try await verificationService.verifyCloud(text: inputText)
            }
        } catch {
            self.error = error
            print("Verification error: \(error)")
        }

        isVerifying = false
    }

    func loadModel() async {
        do {
            try await verificationService.loadModel()
            isModelLoaded = true
        } catch {
            self.error = error
            print("Model loading error: \(error)")
        }
    }

    func generateMockNote() {
        inputText = MockDataGenerator.generateClinicalNote()
    }

    func clearResults() {
        result = nil
        error = nil
    }
}

// MARK: - Mock Data Generator

struct MockDataGenerator {
    static func generateClinicalNote() -> String {
        let names = ["John Smith", "Jane Doe", "Robert Johnson", "Maria Garcia"]
        let hospitals = ["Memorial Hospital", "City Medical Center", "University Health"]
        let complaints = ["chest pain", "shortness of breath", "abdominal pain", "headache"]

        let name = names.randomElement()!
        let hospital = hospitals.randomElement()!
        let complaint = complaints.randomElement()!
        let ssn = "\(Int.random(in: 100...999))-\(Int.random(in: 10...99))-\(Int.random(in: 1000...9999))"
        let mrn = String(format: "%08d", Int.random(in: 1...99999999))
        let phone = "\(Int.random(in: 100...999))-\(Int.random(in: 100...999))-\(Int.random(in: 1000...9999))"
        let dob = "\(Int.random(in: 1...12))/\(Int.random(in: 1...28))/\(Int.random(in: 1950...2000))"
        let email = "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@email.com"

        return """
        ADMISSION NOTE

        Patient: \(name)
        DOB: \(dob)
        SSN: \(ssn)
        MRN: \(mrn)
        Phone: \(phone)
        Email: \(email)

        Facility: \(hospital)
        Date of Admission: \(Int.random(in: 1...12))/\(Int.random(in: 1...28))/2024

        Chief Complaint: \(complaint)

        History of Present Illness:
        \(name) is a \(Int.random(in: 25...85)) year old patient who presents with \(complaint). \
        The patient reports symptoms began approximately \(Int.random(in: 1...14)) days ago. \
        No recent travel or sick contacts.

        Assessment and Plan:
        1. \(complaint.capitalized) - will obtain further workup
        2. Follow up in clinic in 1 week
        """
    }
}

// MARK: - Inline Model Types (In actual app, these come from AareEdge SDK)

enum ComplianceStatus: String, Codable {
    case compliant = "compliant"
    case violation = "violation"
    case error = "error"

    var description: String {
        switch self {
        case .compliant: return "HIPAA Compliant"
        case .violation: return "HIPAA Violation"
        case .error: return "Error"
        }
    }
}

enum PHICategory: String, Codable, CaseIterable {
    case names = "NAMES"
    case geographicSubdivisions = "GEOGRAPHIC_SUBDIVISIONS"
    case dates = "DATES"
    case phoneNumbers = "PHONE_NUMBERS"
    case faxNumbers = "FAX_NUMBERS"
    case emailAddresses = "EMAIL_ADDRESSES"
    case ssn = "SSN"
    case medicalRecordNumbers = "MEDICAL_RECORD_NUMBERS"
    case healthPlanBeneficiaryNumbers = "HEALTH_PLAN_BENEFICIARY_NUMBERS"
    case accountNumbers = "ACCOUNT_NUMBERS"
    case certificateLicenseNumbers = "CERTIFICATE_LICENSE_NUMBERS"
    case vehicleIdentifiers = "VEHICLE_IDENTIFIERS"
    case deviceIdentifiers = "DEVICE_IDENTIFIERS"
    case webUrls = "WEB_URLS"
    case ipAddresses = "IP_ADDRESSES"
    case biometricIdentifiers = "BIOMETRIC_IDENTIFIERS"
    case photographicImages = "PHOTOGRAPHIC_IMAGES"
    case anyOtherUniqueIdentifyingNumber = "ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"

    var description: String {
        switch self {
        case .names: return "Name"
        case .dates: return "Date"
        case .phoneNumbers: return "Phone"
        case .emailAddresses: return "Email"
        case .ssn: return "SSN"
        case .medicalRecordNumbers: return "MRN"
        case .ipAddresses: return "IP Address"
        case .webUrls: return "URL"
        default: return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct PHIEntity: Codable, Identifiable {
    let id: UUID
    let category: PHICategory
    let value: String
    let startIndex: Int
    let endIndex: Int
    let confidence: Double

    var confidencePercent: String {
        String(format: "%.0f%%", confidence * 100)
    }
}

struct VerificationMetadata: Codable {
    let isEdge: Bool
    let latencyMs: Double?
    let modelVersion: String?
    let solverResult: String?
}

struct VerificationResult: Codable {
    let status: ComplianceStatus
    let entities: [PHIEntity]
    let proof: String
    let metadata: VerificationMetadata
}
