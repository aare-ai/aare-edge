# AareEdgeSDK

Swift SDK for on-device PHI detection and policy verification.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aare-ai/aare-edge", from: "1.0.0")
]
```

## Components

### PHIDetector

Detects HIPAA Safe Harbor PHI categories using a CoreML NER model.

```swift
let detector = try PHIDetector(modelURL: modelURL, vocabURL: vocabURL)
let result = try detector.detect("Patient John Smith, SSN: 123-45-6789")

for entity in result.entities {
    print("\(entity.type): \(entity.text)")
}
```

### WordPieceTokenizer

BERT-compatible tokenizer for text preprocessing.

```swift
let tokenizer = try WordPieceTokenizer(vocabURL: vocabURL)
let encoded = tokenizer.encode("Hello world")
```

### EntityExtractor

Converts BIO-tagged predictions to entity spans.

### Z3Lite

Lightweight constraint solver for policy verification.

```swift
let solver = Z3Lite()
let x = solver.intVar("phi_count")
solver.assert(x.eq(0))
solver.bind("phi_count", to: .int(0))
let result = solver.check() // .satisfiable
```

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Model files (licensed separately)

## License

MIT License (SDK code only). Model weights require separate license.
