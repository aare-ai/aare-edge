"""HIPAA Z3 Verification Engine.

Combines DSLM entity extraction with Z3 theorem proving for
formal HIPAA compliance verification.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Union

from z3 import And, Bool, Not, Or, Solver, sat, unsat

from .rules import HIPAARules, PHIDetection, create_violation_explanation


class ComplianceStatus(Enum):
    """HIPAA compliance status."""
    COMPLIANT = "compliant"
    VIOLATION = "violation"
    ERROR = "error"


@dataclass
class VerificationResult:
    """Result of HIPAA verification."""
    status: ComplianceStatus
    entities: List[PHIDetection]
    proof: str
    violations: Optional[Dict[str, Any]] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "status": self.status.value,
            "entities": [
                {
                    "category": e.category,
                    "value": e.value,
                    "start": e.start,
                    "end": e.end,
                    "confidence": e.confidence
                }
                for e in self.entities
            ],
            "proof": self.proof,
            "violations": self.violations,
            "metadata": self.metadata
        }

    def to_json(self) -> str:
        """Convert to JSON string."""
        return json.dumps(self.to_dict(), indent=2)


class HIPAAVerifier:
    """HIPAA compliance verifier using Z3 theorem proving.

    This class provides the core verification logic that combines
    entity detection results with formal Z3 proofs of compliance.
    """

    def __init__(self, config_path: Optional[Union[str, Path]] = None):
        """Initialize the verifier.

        Args:
            config_path: Path to hipaa-v1.json configuration.
        """
        self.rules = HIPAARules(config_path)

    def verify(self, entities: List[PHIDetection]) -> VerificationResult:
        """Verify HIPAA compliance for detected entities.

        Args:
            entities: List of PHI entities detected by the DSLM.

        Returns:
            VerificationResult with compliance status and proof.
        """
        # Create Z3 solver
        solver = Solver()

        # Create constraints from detections
        category_vars = self.rules.create_z3_constraints(entities, solver)

        # Check for any prohibited PHI
        prohibited_categories = self.rules.get_prohibited_categories()
        prohibited_vars = [category_vars[cat] for cat in prohibited_categories
                         if cat in category_vars]

        # The compliance constraint: no prohibited PHI should be detected
        # We check if it's POSSIBLE for no PHI to be detected
        # If UNSAT, that means PHI WAS detected (violation)

        solver.push()  # Save state

        # Assert that we want no prohibited PHI
        if prohibited_vars:
            solver.add(Not(Or(prohibited_vars)))

        result = solver.check()
        solver.pop()  # Restore state

        # Generate result
        if result == unsat:
            # UNSAT means the "no prohibited PHI" constraint cannot be satisfied
            # i.e., prohibited PHI was detected
            violations = create_violation_explanation(entities, self.rules)

            # Generate proof explanation
            proof_lines = ["HIPAA VIOLATION DETECTED", "=" * 40]
            for v in violations["violations"]:
                proof_lines.append(f"Category: {v['category']}")
                proof_lines.append(f"  Value: {v['value']}")
                proof_lines.append(f"  Position: {v['location']['start']}-{v['location']['end']}")
                for rule in v["violated_rules"]:
                    proof_lines.append(f"  Violated: {rule['id']} - {rule['description']}")
                proof_lines.append("")

            proof_lines.append(f"Total violations: {violations['num_violations']}")
            proof_lines.append(f"Categories: {', '.join(violations['categories_violated'])}")
            proof = "\n".join(proof_lines)

            return VerificationResult(
                status=ComplianceStatus.VIOLATION,
                entities=entities,
                proof=proof,
                violations=violations,
                metadata={"solver_result": "unsat"}
            )
        else:
            # SAT means it's satisfiable to have no prohibited PHI
            # i.e., the document is compliant
            proof_lines = [
                "HIPAA COMPLIANT",
                "=" * 40,
                "No prohibited PHI identifiers detected.",
                "",
                "Verification passed for all 18 HIPAA Safe Harbor categories:",
            ]

            for cat in prohibited_categories:
                detected = any(e.category == cat for e in entities)
                status = "✗ DETECTED" if detected else "✓ Clear"
                proof_lines.append(f"  {cat}: {status}")

            proof = "\n".join(proof_lines)

            return VerificationResult(
                status=ComplianceStatus.COMPLIANT,
                entities=entities,
                proof=proof,
                violations=None,
                metadata={"solver_result": "sat"}
            )

    def verify_text(
        self,
        text: str,
        entity_extractor: Optional[Callable] = None
    ) -> VerificationResult:
        """Verify HIPAA compliance for a text document.

        This is a convenience method that combines entity extraction
        with verification. If no extractor is provided, returns an
        error result.

        Args:
            text: Text to verify.
            entity_extractor: Function that takes text and returns list of PHIDetection.

        Returns:
            VerificationResult with compliance status.
        """
        if entity_extractor is None:
            return VerificationResult(
                status=ComplianceStatus.ERROR,
                entities=[],
                proof="No entity extractor provided. Use verify() with pre-extracted entities.",
                violations=None,
                metadata={"error": "no_extractor"}
            )

        try:
            entities = entity_extractor(text)
            return self.verify(entities)
        except Exception as e:
            return VerificationResult(
                status=ComplianceStatus.ERROR,
                entities=[],
                proof=f"Error during verification: {str(e)}",
                violations=None,
                metadata={"error": str(e)}
            )

    def batch_verify(
        self,
        documents: List[List[PHIDetection]]
    ) -> List[VerificationResult]:
        """Verify multiple documents.

        Args:
            documents: List of entity lists, one per document.

        Returns:
            List of VerificationResult objects.
        """
        return [self.verify(entities) for entities in documents]


def verify_from_json(
    entities_json: Union[str, dict],
    config_path: Optional[Union[str, Path]] = None
) -> VerificationResult:
    """Verify from JSON entity representation.

    Args:
        entities_json: JSON string or dict with entity list.
        config_path: Path to HIPAA config.

    Returns:
        VerificationResult.
    """
    if isinstance(entities_json, str):
        entities_json = json.loads(entities_json)

    entities = [
        PHIDetection(
            category=e["category"],
            value=e.get("value", ""),
            start=e.get("start", 0),
            end=e.get("end", 0),
            confidence=e.get("confidence", 1.0)
        )
        for e in entities_json.get("entities", entities_json)
    ]

    verifier = HIPAAVerifier(config_path)
    return verifier.verify(entities)


def main():
    """CLI entry point for verification."""
    import argparse

    parser = argparse.ArgumentParser(description="Verify HIPAA compliance")
    parser.add_argument("--entities", "-e", help="JSON file with detected entities")
    parser.add_argument("--output", "-o", help="Output file for results")
    parser.add_argument("--format", choices=["json", "text"], default="text",
                       help="Output format")

    args = parser.parse_args()

    # Demo mode if no input
    if not args.entities:
        print("HIPAA Verifier Demo")
        print("=" * 60)

        # Create some test detections
        test_entities = [
            PHIDetection("NAMES", "John Smith", 10, 20, 0.95),
            PHIDetection("SSN", "123-45-6789", 30, 41, 0.99),
            PHIDetection("DATES", "01/15/1985", 50, 60, 0.88),
        ]

        verifier = HIPAAVerifier()
        result = verifier.verify(test_entities)

        print(f"\nStatus: {result.status.value}")
        print(f"\nProof:\n{result.proof}")

        # Test compliant case
        print("\n" + "=" * 60)
        print("Testing compliant document (no PHI)...")
        result_clean = verifier.verify([])
        print(f"\nStatus: {result_clean.status.value}")
        print(f"\nProof:\n{result_clean.proof}")

        return

    # Load entities from file
    with open(args.entities) as f:
        entities_data = json.load(f)

    result = verify_from_json(entities_data)

    # Output
    if args.format == "json":
        output = result.to_json()
    else:
        output = f"Status: {result.status.value}\n\n{result.proof}"

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
    else:
        print(output)


if __name__ == "__main__":
    main()
