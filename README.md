# Aare Edge: On-Device NER & Policy Verification

A neuro-symbolic SDK for real-time Named Entity Recognition (NER) and policy verification, designed to run entirely on-device.

## Overview

Aare Edge combines fine-tuned transformer models (CoreML) with Z3Lite constraint solving to provide verifiable entity detection and policy compliance checks without sending data to the cloud.

### Key Features

- **On-Device Processing**: All inference runs locally, no data leaves the device
- **Domain Agnostic**: Use with any NER model and entity schema
- **CoreML Optimized**: Native iOS/macOS performance with Neural Engine acceleration
- **Policy Verification**: Z3Lite constraint solver for custom compliance rules
- **Swift Package**: Easy integration via Swift Package Manager

## Use Cases

- **Healthcare**: HIPAA PHI detection and de-identification
- **Finance**: PII detection for regulatory compliance
- **Legal**: Contract entity extraction and validation
- **Custom**: Any domain-specific NER task

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Aare Edge SDK                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   NER Model     │───▶│  Entity Extraction              │ │
│  │   (CoreML)      │    │  BIO Labels → Entities          │ │
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
- CoreML model (BIO-tagged NER)

## Quick Start

### Entity Detection

```swift
import AareEdgeSDK

// Initialize with your model and vocabulary
let detector = try PHIDetector(
    modelURL: modelURL,
    vocabURL: vocabURL,
    configURL: labelConfigURL  // Your entity label schema
)

// Detect entities in text
let result = try detector.detect("Your input text here")

// Process results
for entity in result.entities {
    print("\(entity.type): \(entity.text) [\(entity.startOffset)-\(entity.endOffset)]")
}
```

### Policy Verification

```swift
import AareEdgeSDK

let solver = Z3Lite()

// Define policy variables
let entityCount = solver.intVar("entity_count")
let isRestricted = solver.boolVar("is_restricted")

// Policy: if restricted context, entity count must be 0
solver.assert(isRestricted.implies(entityCount.eq(0)))

// Bind actual values
solver.bind("is_restricted", to: .bool(true))
solver.bind("entity_count", to: .int(result.entities.count))

// Check compliance
let check = solver.check()
if check.isUnsatisfiable {
    print("Policy violated")
}
```

## Project Structure

```
aare-edge/
├── AareEdgeSDK/           # Swift SDK (open source)
│   ├── Sources/
│   │   └── AareEdgeSDK/
│   │       ├── PHIDetector.swift      # NER inference
│   │       ├── Tokenizer.swift        # WordPiece tokenizer
│   │       ├── EntityExtractor.swift  # BIO → entities
│   │       └── Z3Lite.swift           # Constraint solver
│   └── Tests/
├── AareEdgeDemo/          # Reference iOS app (HIPAA example)
│   └── AareEdgeDemo/
├── configs/               # Example label configurations
│   └── hipaa-v1.json      # HIPAA Safe Harbor schema
└── README.md
```

## Example: HIPAA PHI Detection

The included demo app shows HIPAA PHI detection as an example use case:

```swift
// HIPAA-specific label config
let detector = try PHIDetector(
    modelURL: hipaaModelURL,
    vocabURL: vocabURL,
    configURL: Bundle.main.url(forResource: "hipaa-v1", withExtension: "json")
)

let result = try detector.detect("Patient John Smith, SSN: 123-45-6789")
// Detects: NAME: "John Smith", SSN: "123-45-6789"
```

The HIPAA config includes 18 Safe Harbor categories: NAME, LOCATION, DATE, PHONE, FAX, EMAIL, SSN, MRN, HEALTH_PLAN, ACCOUNT, LICENSE, VEHICLE, DEVICE, URL, IP, BIOMETRIC, PHOTO, OTHER.

## Custom Domain Configuration

Create your own label configuration JSON:

```json
{
  "label_list": [
    "O",
    "B-PERSON", "I-PERSON",
    "B-ORG", "I-ORG",
    "B-AMOUNT", "I-AMOUNT",
    "B-DATE", "I-DATE"
  ],
  "num_labels": 9
}
```

Train a model with your schema, convert to CoreML, and use with the SDK.

## API Reference

### Detector

```swift
// Initialize
let detector = try PHIDetector(modelURL: url, vocabURL: url, configURL: url)

// Basic detection
let result = try detector.detect(text)

// Detection with confidence scores
let detailed = try detector.detectWithScores(text)
```

### Detection Result

```swift
struct PHIDetectionResult {
    let text: String
    let entities: [PHIEntity]
    let tokenCount: Int
    var containsPHI: Bool { get }
    func entities(ofType: String) -> [PHIEntity]
}

struct PHIEntity {
    let type: String       // Entity type from your schema
    let text: String       // The detected text
    let startOffset: Int   // Character offset
    let endOffset: Int
    let confidence: Float
}
```

### Z3Lite Constraint Solver

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

// Push/pop for scoped constraints
solver.push()
solver.assert(n.lt(10))
solver.check()
solver.pop()  // Reverts to previous state
```

## License

- **SDK Code**: MIT License (open source)
- **Model Weights**: Trained models are licensed separately (contact info@aare.ai)

The example label schema in `configs/hipaa-v1.json` is open source under MIT.

## Contributing

Contributions to the SDK are welcome!

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

- GitHub Issues: [github.com/aare-ai/aare-edge/issues](https://github.com/aare-ai/aare-edge/issues)
- Email: info@aare.ai
