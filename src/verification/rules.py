"""HIPAA Compliance Rules for Z3 Verification.

Defines formal rules for HIPAA Safe Harbor de-identification based on
45 CFR 164.514(b)(2). These rules are used by the Z3 solver to prove
compliance or generate violation explanations.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

from z3 import And, Bool, Implies, Not, Or, Solver, sat, unsat

import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from src.data.label_mapper import load_hipaa_config


@dataclass
class PHIDetection:
    """Represents a detected PHI entity."""
    category: str
    value: str
    start: int
    end: int
    confidence: float = 1.0


@dataclass
class HIPAARule:
    """A HIPAA compliance rule."""
    id: str
    name: str
    description: str
    categories: List[str]
    prohibition_type: str  # "absolute" or "conditional"
    condition: Optional[str] = None  # For conditional rules (e.g., age > 89)


class HIPAARules:
    """Collection of HIPAA Safe Harbor de-identification rules.

    These rules are derived from 45 CFR 164.514(b)(2) and define
    what constitutes PHI that must be removed for de-identification.
    """

    def __init__(self, config_path: Optional[Union[str, Path]] = None):
        """Initialize HIPAA rules.

        Args:
            config_path: Path to hipaa-v1.json configuration.
        """
        self.config = load_hipaa_config(config_path)
        self.categories = {cat["name"]: cat for cat in self.config["categories"]}
        self._rules = self._build_rules()

    def _build_rules(self) -> List[HIPAARule]:
        """Build the list of HIPAA rules."""
        rules = []

        # Core 18 identifiers - absolute prohibitions
        absolute_prohibitions = [
            ("R1", "NAMES", "Names must be removed"),
            ("R2", "GEOGRAPHIC_SUBDIVISIONS", "Geographic data smaller than state must be removed"),
            ("R3", "DATES", "Dates (except year) must be removed"),
            ("R4", "PHONE_NUMBERS", "Phone numbers must be removed"),
            ("R5", "FAX_NUMBERS", "Fax numbers must be removed"),
            ("R6", "EMAIL_ADDRESSES", "Email addresses must be removed"),
            ("R7", "SSN", "Social Security numbers must be removed"),
            ("R8", "MEDICAL_RECORD_NUMBERS", "Medical record numbers must be removed"),
            ("R9", "HEALTH_PLAN_BENEFICIARY_NUMBERS", "Health plan beneficiary numbers must be removed"),
            ("R10", "ACCOUNT_NUMBERS", "Account numbers must be removed"),
            ("R11", "CERTIFICATE_LICENSE_NUMBERS", "Certificate/license numbers must be removed"),
            ("R12", "VEHICLE_IDENTIFIERS", "Vehicle identifiers must be removed"),
            ("R13", "DEVICE_IDENTIFIERS", "Device identifiers must be removed"),
            ("R14", "WEB_URLS", "Web URLs must be removed"),
            ("R15", "IP_ADDRESSES", "IP addresses must be removed"),
            ("R16", "BIOMETRIC_IDENTIFIERS", "Biometric identifiers must be removed"),
            ("R17", "PHOTOGRAPHIC_IMAGES", "Full-face photos must be removed"),
            ("R18", "ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER", "Other unique identifiers must be removed"),
        ]

        for rule_id, category, description in absolute_prohibitions:
            rules.append(HIPAARule(
                id=rule_id,
                name=f"Prohibition of {category}",
                description=description,
                categories=[category],
                prohibition_type="absolute"
            ))

        # Conditional rules (for extended verification)
        conditional_rules = [
            HIPAARule(
                id="R19",
                name="Age Over 89",
                description="Ages over 89 must be aggregated to 90+",
                categories=["DATES"],
                prohibition_type="conditional",
                condition="age > 89"
            ),
            HIPAARule(
                id="R20",
                name="ZIP Code Population",
                description="ZIP codes with population < 20,000 must be zeroed",
                categories=["GEOGRAPHIC_SUBDIVISIONS"],
                prohibition_type="conditional",
                condition="zip_population < 20000"
            ),
        ]

        rules.extend(conditional_rules)
        return rules

    def get_rules(self) -> List[HIPAARule]:
        """Get all HIPAA rules."""
        return self._rules

    def get_rule_by_id(self, rule_id: str) -> Optional[HIPAARule]:
        """Get a specific rule by ID."""
        for rule in self._rules:
            if rule.id == rule_id:
                return rule
        return None

    def get_rules_for_category(self, category: str) -> List[HIPAARule]:
        """Get all rules that apply to a category."""
        return [r for r in self._rules if category in r.categories]

    def get_prohibited_categories(self) -> List[str]:
        """Get list of all prohibited categories."""
        return [cat["name"] for cat in self.config["categories"] if cat.get("prohibited", False)]

    def is_prohibited(self, category: str) -> bool:
        """Check if a category is prohibited."""
        return category in self.get_prohibited_categories()

    def create_z3_constraints(self, detections: List[PHIDetection], solver: Solver) -> Dict[str, Bool]:
        """Create Z3 constraints for detected PHI entities.

        Args:
            detections: List of detected PHI entities.
            solver: Z3 Solver instance.

        Returns:
            Dictionary mapping category names to Z3 Bool variables.
        """
        # Create boolean variables for each category
        category_vars = {}
        for category in self.get_prohibited_categories():
            category_vars[category] = Bool(f"{category}_detected")

        # Set variables based on detections
        detected_categories = {d.category for d in detections}

        for category, var in category_vars.items():
            if category in detected_categories:
                solver.add(var == True)
            else:
                solver.add(var == False)

        return category_vars

    def add_compliance_rule(self, solver: Solver, category_vars: Dict[str, Bool]):
        """Add the main compliance rule: no prohibited PHI should be present.

        The rule states: For the document to be compliant, none of the
        prohibited PHI categories should be detected.

        Args:
            solver: Z3 Solver instance.
            category_vars: Dictionary of category Bool variables.
        """
        # Compliance means NO prohibited categories are detected
        prohibited_detected = [var for cat, var in category_vars.items()
                              if self.is_prohibited(cat)]

        if prohibited_detected:
            # Document is compliant IFF no prohibited PHI is detected
            solver.add(Not(Or(prohibited_detected)))


def create_violation_explanation(
    detections: List[PHIDetection],
    rules: HIPAARules
) -> Dict[str, Any]:
    """Create a human-readable explanation of violations.

    Args:
        detections: List of detected PHI entities.
        rules: HIPAARules instance.

    Returns:
        Dictionary with violation details.
    """
    violations = []
    for detection in detections:
        if rules.is_prohibited(detection.category):
            applicable_rules = rules.get_rules_for_category(detection.category)
            violations.append({
                "category": detection.category,
                "value": detection.value,
                "location": {"start": detection.start, "end": detection.end},
                "confidence": detection.confidence,
                "violated_rules": [
                    {"id": r.id, "name": r.name, "description": r.description}
                    for r in applicable_rules
                ]
            })

    return {
        "num_violations": len(violations),
        "violations": violations,
        "categories_violated": list(set(v["category"] for v in violations))
    }


if __name__ == "__main__":
    # Test rules
    rules = HIPAARules()

    print("HIPAA Rules:")
    print("=" * 60)
    for rule in rules.get_rules():
        print(f"{rule.id}: {rule.name}")
        print(f"    Categories: {rule.categories}")
        print(f"    Type: {rule.prohibition_type}")
        if rule.condition:
            print(f"    Condition: {rule.condition}")
        print()

    print(f"\nProhibited categories: {rules.get_prohibited_categories()}")
