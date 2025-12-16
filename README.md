# Aare Edge: On-Device HIPAA PHI Detection

A neuro-symbolic system for real-time PHI (Protected Health Information) detection and HIPAA compliance verification, designed to run entirely on-device.

## Overview

Aare Edge combines a fine-tuned DistilBERT model for Named Entity Recognition (NER) with Z3Lite constraint solving to provide verifiable HIPAA compliance checks without sending sensitive data to the cloud.

### Key Features

- **On-Device Processing**: All PHI detection runs locally—no data leaves the device
- **18 HIPAA Categories**: Full coverage of the 18 PHI identifier types defined by HIPAA Safe Harbor
- **CoreML Optimized**: Native iOS/macOS performance with Neural Engine acceleration
- **Policy Verification**: Z3Lite constraint solver for compliance rule checking
- **Swift Package**: Easy integration via Swift Package Manager

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Aare Edge SDK                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   DistilBERT    │───▶│  Entity Extraction              │ │
│  │   CoreML Model  │    │  BIO Labels → PHI Entities      │ │
│  └─────────────────┘    └───────────────┬─────────────────┘ │
│                                         │                   │
│                                         ▼                   │
│                         ┌─────────────────────────────────┐ │
│                         │   Z3Lite Verification           │ │
│                         │   Policy Rules → SAT/UNSAT      │ │
│                         └───────────────┬─────────────────┘ │
│                                         │                   │
│                                         ▼                   │
│                         ┌─────────────────────────────────┐ │
│                         │   Result + Verification         │ │
│                         │   {entities, policyStatus}      │ │
│                         └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## PHI Categories (HIPAA Safe Harbor 18)

| # | Category | Description |
|---|----------|-------------|
| 1 | NAME | Patient and provider names |
| 2 | LOCATION | Addresses, cities, zip codes |
| 3 | DATE | Birth dates, admission dates, ages over 89 |
| 4 | PHONE | Telephone numbers |
| 5 | FAX | Fax numbers |
| 6 | EMAIL | Email addresses |
| 7 | SSN | Social Security numbers |
| 8 | MRN | Medical record numbers |
| 9 | HEALTH_PLAN | Health plan beneficiary numbers |
| 10 | ACCOUNT | Account numbers |
| 11 | LICENSE | Certificate/license numbers |
| 12 | VEHICLE | Vehicle identifiers and serial numbers |
| 13 | DEVICE | Medical device identifiers |
| 14 | URL | Web URLs |
| 15 | IP | IP addresses |
| 16 | BIOMETRIC | Fingerprints, voice prints |
| 17 | PHOTO | Full face photographic images |
| 18 | OTHER | Any other unique identifiers |

## Installation

### Swift Package Manager

Add AareEdgeSDK to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aare-ai/aare-edge", from: "1.0.0")
]
```

Or add via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/aare-ai/aare-edge`

### Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- CoreML model files (licensed separately)

## Quick Start

### PHI Detection

```swift
import AareEdgeSDK

// Initialize with your model and vocabulary files
let detector = try PHIDetector(
    modelURL: modelURL,
    vocabURL: vocabURL
)

// Detect PHI in text
let result = try detector.detect("Patient John Smith, DOB: 01/15/1985")

// Check results
if result.containsPHI {
    for entity in result.entities {
        print("\(entity.type): \(entity.text)")
        // NAME: John Smith
        // DATE: 01/15/1985
    }
}
```

### Policy Verification

```swift
import AareEdgeSDK

let solver = Z3Lite()

// Define policy variables
let phiCount = solver.intVar("phi_count")
let isPublic = solver.boolVar("is_public")

// Policy: if public release, PHI count must be 0
solver.assert(isPublic.implies(phiCount.eq(0)))

// Bind actual values
solver.bind("is_public", to: .bool(true))
solver.bind("phi_count", to: .int(result.entities.count))

// Check compliance
let check = solver.check()
if check.isUnsatisfiable {
    print("Policy violated: PHI detected in public release")
}
```

## Project Structure

```
aare-edge/
├── AareEdgeSDK/           # Swift SDK (open source)
│   ├── Sources/
│   │   └── AareEdgeSDK/
│   │       ├── PHIDetector.swift
│   │       ├── Tokenizer.swift
│   │       ├── EntityExtractor.swift
│   │       └── Z3Lite.swift
│   └── Tests/
├── AareEdgeDemo/          # Reference iOS app
│   └── AareEdgeDemo/
│       ├── ContentView.swift
│       ├── PolicyVerificationView.swift
│       └── AboutView.swift
├── configs/               # Label configurations
│   └── hipaa-v1.json
└── docs/                  # Documentation
```

## Demo App

The AareEdgeDemo app demonstrates:

- **PHI Detection**: Scan text for sensitive information
- **Policy Verification**: Check compliance with custom rules
- **Sample Data**: Pre-loaded examples for testing

To run the demo:

1. Open `AareEdgeDemo` in Xcode
2. Add your `hipaa_ner.mlpackage` and `vocab.txt` to the bundle
3. Build and run on iOS device or simulator

## API Reference

### PHIDetector

```swift
// Initialize
let detector = try PHIDetector(modelURL: url, vocabURL: url)

// Basic detection
let result = try detector.detect(text)

// Detection with confidence scores
let detailed = try detector.detectWithScores(text)
```

### PHIDetectionResult

```swift
struct PHIDetectionResult {
    let text: String
    let entities: [PHIEntity]
    let tokenCount: Int
    var containsPHI: Bool { get }
    func entities(ofType: String) -> [PHIEntity]
}

struct PHIEntity {
    let type: String      // e.g., "NAME", "SSN"
    let text: String      // The detected text
    let startOffset: Int  // Character offset
    let endOffset: Int
    let confidence: Float
}
```

### Z3Lite

```swift
let solver = Z3Lite()

// Create variables
let x = solver.boolVar("x")
let n = solver.intVar("n")
let f = solver.floatVar("f")
let s = solver.stringVar("s")

// Add constraints
solver.assert(x)
solver.assert(n.gt(0))
solver.assert(x.implies(n.eq(5)))

// Bind values and check
solver.bind("x", to: .bool(true))
let result = solver.check() // .satisfiable or .unsatisfiable

// Verify a property holds
let verification = solver.verify(n.gt(0)) // .holds or .counterexample
```

## License

- **SDK Code**: MIT License (open source)
- **Model Weights**: Proprietary (contact sales@aare.ai for licensing)

The label schema in `configs/hipaa-v1.json` is open source under MIT.

## Contributing

Contributions to the SDK are welcome! Please see our contributing guidelines.

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

- GitHub Issues: [github.com/aare-ai/aare-edge/issues](https://github.com/aare-ai/aare-edge/issues)
- Documentation: [docs.aare.ai](https://docs.aare.ai)
- Email: support@aare.ai
