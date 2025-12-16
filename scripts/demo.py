#!/usr/bin/env python3
"""
Aare Edge Demo Script

Demonstrates the full verification pipeline:
1. Extract PHI entities from text
2. Run Z3 verification
3. Output compliance result with proof
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.inference.extractor import MockExtractor
from src.verification.verifier import HIPAAVerifier
from src.verification.rules import PHIDetection


def demo():
    """Run the Aare Edge demo."""
    print("=" * 60)
    print("Aare Edge: On-Device HIPAA Verification Demo")
    print("=" * 60)

    # Sample clinical notes
    samples = [
        {
            "name": "Compliant Note",
            "text": "The patient presents with mild fatigue and reports sleeping poorly. "
                    "Vital signs are within normal limits. "
                    "Recommend follow-up in two weeks."
        },
        {
            "name": "Note with PHI",
            "text": "Patient John Smith (SSN: 123-45-6789) was admitted on 01/15/2024. "
                    "Contact: john.smith@email.com, phone 555-123-4567. "
                    "MRN: 12345678. Diagnosis: Type 2 Diabetes."
        },
        {
            "name": "Note with Multiple PHI Types",
            "text": "ADMISSION NOTE\n"
                    "Patient: Jane Doe, DOB: 03/22/1985\n"
                    "Address: 123 Main Street, Boston, MA 02115\n"
                    "Insurance: Member ID ABC123456, Policy 9876543210\n"
                    "Device: Pacemaker S/N PM-12345\n"
                    "Login from IP: 192.168.1.100"
        }
    ]

    # Initialize components
    extractor = MockExtractor()  # Use mock for demo (no model required)
    verifier = HIPAAVerifier()

    for sample in samples:
        print(f"\n{'=' * 60}")
        print(f"Sample: {sample['name']}")
        print(f"{'=' * 60}")
        print(f"\nInput text:\n{sample['text']}")

        # Step 1: Extract entities
        print("\n--- Entity Extraction ---")
        entities = extractor.extract(sample['text'])

        if entities:
            print(f"Found {len(entities)} PHI entities:")
            for e in entities:
                print(f"  • {e.category}: '{e.value}' "
                      f"[{e.start}:{e.end}] (conf: {e.confidence:.0%})")
        else:
            print("No PHI entities detected by regex patterns.")

        # Step 2: Z3 Verification
        print("\n--- Z3 Verification ---")
        result = verifier.verify(entities)

        print(f"\nStatus: {result.status.value.upper()}")
        print(f"\nProof:\n{result.proof}")

    print(f"\n{'=' * 60}")
    print("Demo complete!")
    print("=" * 60)


if __name__ == "__main__":
    demo()
