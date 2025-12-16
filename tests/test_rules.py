"""Unit tests for HIPAA rules module.

Tests the PHIDetection dataclass, HIPAARules class, and related functions
for managing HIPAA Safe Harbor de-identification rules.
"""

import json
import sys
from pathlib import Path

import pytest
from z3 import Bool, Solver, sat, unsat

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.verification.rules import (
    HIPAARules,
    PHIDetection,
    create_violation_explanation,
)


class TestPHIDetection:
    """Test the PHIDetection dataclass."""

    def test_phi_detection_creation(self):
        """Test creating a PHIDetection instance."""
        detection = PHIDetection(
            category="NAMES",
            value="John Smith",
            start=0,
            end=10,
            confidence=0.95
        )

        assert detection.category == "NAMES"
        assert detection.value == "John Smith"
        assert detection.start == 0
        assert detection.end == 10
        assert detection.confidence == 0.95

    def test_phi_detection_default_confidence(self):
        """Test that confidence defaults to 1.0."""
        detection = PHIDetection(
            category="SSN",
            value="123-45-6789",
            start=10,
            end=21
        )

        assert detection.confidence == 1.0

    def test_phi_detection_equality(self):
        """Test PHIDetection equality comparison."""
        det1 = PHIDetection("NAMES", "John", 0, 4, 0.9)
        det2 = PHIDetection("NAMES", "John", 0, 4, 0.9)
        det3 = PHIDetection("SSN", "123-45-6789", 5, 16, 0.95)

        assert det1 == det2
        assert det1 != det3


class TestHIPAARules:
    """Test the HIPAARules class."""

    @pytest.fixture
    def rules(self):
        """Create a HIPAARules instance for testing."""
        return HIPAARules()

    def test_initialization(self, rules):
        """Test HIPAARules initialization."""
        assert rules is not None
        assert hasattr(rules, 'config')
        assert hasattr(rules, 'categories')
        assert len(rules._rules) > 0

    def test_config_loading(self, rules):
        """Test that config is loaded correctly."""
        assert "categories" in rules.config
        assert "label_list" in rules.config
        assert "num_labels" in rules.config
        assert rules.config["num_labels"] == 37

    def test_get_rules(self, rules):
        """Test retrieving all rules."""
        all_rules = rules.get_rules()
        assert isinstance(all_rules, list)
        assert len(all_rules) >= 18  # At least 18 core rules

        # Check that we have the expected number (18 absolute + 2 conditional)
        assert len(all_rules) == 20

    def test_get_rule_by_id(self, rules):
        """Test retrieving a specific rule by ID."""
        rule = rules.get_rule_by_id("R1")
        assert rule is not None
        assert rule.id == "R1"
        assert rule.name == "Prohibition of NAMES"
        assert "NAMES" in rule.categories
        assert rule.prohibition_type == "absolute"

        # Test non-existent rule
        assert rules.get_rule_by_id("R999") is None

    def test_all_18_core_rules_exist(self, rules):
        """Test that all 18 HIPAA Safe Harbor rules exist."""
        expected_rules = [
            ("R1", "NAMES"),
            ("R2", "GEOGRAPHIC_SUBDIVISIONS"),
            ("R3", "DATES"),
            ("R4", "PHONE_NUMBERS"),
            ("R5", "FAX_NUMBERS"),
            ("R6", "EMAIL_ADDRESSES"),
            ("R7", "SSN"),
            ("R8", "MEDICAL_RECORD_NUMBERS"),
            ("R9", "HEALTH_PLAN_BENEFICIARY_NUMBERS"),
            ("R10", "ACCOUNT_NUMBERS"),
            ("R11", "CERTIFICATE_LICENSE_NUMBERS"),
            ("R12", "VEHICLE_IDENTIFIERS"),
            ("R13", "DEVICE_IDENTIFIERS"),
            ("R14", "WEB_URLS"),
            ("R15", "IP_ADDRESSES"),
            ("R16", "BIOMETRIC_IDENTIFIERS"),
            ("R17", "PHOTOGRAPHIC_IMAGES"),
            ("R18", "ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"),
        ]

        for rule_id, category in expected_rules:
            rule = rules.get_rule_by_id(rule_id)
            assert rule is not None, f"Rule {rule_id} not found"
            assert category in rule.categories, f"Category {category} not in rule {rule_id}"
            assert rule.prohibition_type == "absolute"

    def test_conditional_rules(self, rules):
        """Test conditional rules for extended verification."""
        # Rule R19 - Age over 89
        rule_r19 = rules.get_rule_by_id("R19")
        assert rule_r19 is not None
        assert rule_r19.prohibition_type == "conditional"
        assert rule_r19.condition == "age > 89"
        assert "DATES" in rule_r19.categories

        # Rule R20 - ZIP code population
        rule_r20 = rules.get_rule_by_id("R20")
        assert rule_r20 is not None
        assert rule_r20.prohibition_type == "conditional"
        assert rule_r20.condition == "zip_population < 20000"
        assert "GEOGRAPHIC_SUBDIVISIONS" in rule_r20.categories

    def test_get_rules_for_category(self, rules):
        """Test retrieving rules for a specific category."""
        names_rules = rules.get_rules_for_category("NAMES")
        assert len(names_rules) >= 1
        assert all("NAMES" in r.categories for r in names_rules)

        dates_rules = rules.get_rules_for_category("DATES")
        assert len(dates_rules) >= 1  # At least R3 and R19
        assert all("DATES" in r.categories for r in dates_rules)

    def test_get_prohibited_categories(self, rules):
        """Test retrieving all prohibited categories."""
        prohibited = rules.get_prohibited_categories()

        assert isinstance(prohibited, list)
        assert len(prohibited) == 18  # All 18 HIPAA categories

        # Check that all expected categories are present
        expected_categories = [
            "NAMES",
            "GEOGRAPHIC_SUBDIVISIONS",
            "DATES",
            "PHONE_NUMBERS",
            "FAX_NUMBERS",
            "EMAIL_ADDRESSES",
            "SSN",
            "MEDICAL_RECORD_NUMBERS",
            "HEALTH_PLAN_BENEFICIARY_NUMBERS",
            "ACCOUNT_NUMBERS",
            "CERTIFICATE_LICENSE_NUMBERS",
            "VEHICLE_IDENTIFIERS",
            "DEVICE_IDENTIFIERS",
            "WEB_URLS",
            "IP_ADDRESSES",
            "BIOMETRIC_IDENTIFIERS",
            "PHOTOGRAPHIC_IMAGES",
            "ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER",
        ]

        for category in expected_categories:
            assert category in prohibited, f"Category {category} not in prohibited list"

    def test_is_prohibited(self, rules):
        """Test checking if a category is prohibited."""
        # Test all 18 prohibited categories
        prohibited_categories = [
            "NAMES", "GEOGRAPHIC_SUBDIVISIONS", "DATES", "PHONE_NUMBERS",
            "FAX_NUMBERS", "EMAIL_ADDRESSES", "SSN", "MEDICAL_RECORD_NUMBERS",
            "HEALTH_PLAN_BENEFICIARY_NUMBERS", "ACCOUNT_NUMBERS",
            "CERTIFICATE_LICENSE_NUMBERS", "VEHICLE_IDENTIFIERS",
            "DEVICE_IDENTIFIERS", "WEB_URLS", "IP_ADDRESSES",
            "BIOMETRIC_IDENTIFIERS", "PHOTOGRAPHIC_IMAGES",
            "ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"
        ]

        for category in prohibited_categories:
            assert rules.is_prohibited(category), f"Category {category} should be prohibited"

        # Test that a non-existent category is not prohibited
        assert not rules.is_prohibited("NONEXISTENT_CATEGORY")

    def test_create_z3_constraints_no_detections(self, rules):
        """Test creating Z3 constraints with no detections."""
        solver = Solver()
        detections = []

        category_vars = rules.create_z3_constraints(detections, solver)

        # Should have a variable for each prohibited category
        assert len(category_vars) == 18

        # All variables should be False
        result = solver.check()
        assert result == sat

    def test_create_z3_constraints_with_detections(self, rules):
        """Test creating Z3 constraints with PHI detections."""
        solver = Solver()
        detections = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("SSN", "123-45-6789", 20, 31, 0.99),
        ]

        category_vars = rules.create_z3_constraints(detections, solver)

        # Check that variables are created
        assert "NAMES" in category_vars
        assert "SSN" in category_vars

        # Solver should have constraints
        result = solver.check()
        assert result == sat

    def test_create_z3_constraints_variable_types(self, rules):
        """Test that Z3 constraints create proper boolean variables."""
        solver = Solver()
        detections = [PHIDetection("NAMES", "Test", 0, 4, 1.0)]

        category_vars = rules.create_z3_constraints(detections, solver)

        # Check that all values are Z3 Bool variables
        for var in category_vars.values():
            assert isinstance(var, Bool)

    def test_add_compliance_rule(self, rules):
        """Test adding the main compliance rule to solver."""
        solver = Solver()
        detections = []

        category_vars = rules.create_z3_constraints(detections, solver)
        rules.add_compliance_rule(solver, category_vars)

        # With no detections, should be satisfiable (compliant)
        result = solver.check()
        assert result == sat

    def test_add_compliance_rule_with_violations(self, rules):
        """Test compliance rule with prohibited PHI detected."""
        solver = Solver()
        detections = [PHIDetection("NAMES", "John Smith", 0, 10, 0.95)]

        category_vars = rules.create_z3_constraints(detections, solver)
        rules.add_compliance_rule(solver, category_vars)

        # With prohibited PHI, should be unsatisfiable (violation)
        result = solver.check()
        assert result == unsat


class TestCreateViolationExplanation:
    """Test the create_violation_explanation function."""

    @pytest.fixture
    def rules(self):
        """Create a HIPAARules instance for testing."""
        return HIPAARules()

    def test_no_violations(self, rules):
        """Test explanation with no violations."""
        detections = []
        explanation = create_violation_explanation(detections, rules)

        assert explanation["num_violations"] == 0
        assert len(explanation["violations"]) == 0
        assert len(explanation["categories_violated"]) == 0

    def test_single_violation(self, rules):
        """Test explanation with a single violation."""
        detections = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95)
        ]

        explanation = create_violation_explanation(detections, rules)

        assert explanation["num_violations"] == 1
        assert len(explanation["violations"]) == 1
        assert explanation["categories_violated"] == ["NAMES"]

        violation = explanation["violations"][0]
        assert violation["category"] == "NAMES"
        assert violation["value"] == "John Smith"
        assert violation["location"]["start"] == 0
        assert violation["location"]["end"] == 10
        assert violation["confidence"] == 0.95
        assert len(violation["violated_rules"]) > 0

    def test_multiple_violations(self, rules):
        """Test explanation with multiple violations."""
        detections = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("SSN", "123-45-6789", 20, 31, 0.99),
            PHIDetection("EMAIL_ADDRESSES", "john@example.com", 40, 56, 0.88),
        ]

        explanation = create_violation_explanation(detections, rules)

        assert explanation["num_violations"] == 3
        assert len(explanation["violations"]) == 3
        assert set(explanation["categories_violated"]) == {"NAMES", "SSN", "EMAIL_ADDRESSES"}

    def test_violation_has_rule_details(self, rules):
        """Test that violation explanation includes rule details."""
        detections = [PHIDetection("SSN", "123-45-6789", 0, 11, 1.0)]

        explanation = create_violation_explanation(detections, rules)

        violation = explanation["violations"][0]
        assert "violated_rules" in violation
        assert len(violation["violated_rules"]) > 0

        rule_info = violation["violated_rules"][0]
        assert "id" in rule_info
        assert "name" in rule_info
        assert "description" in rule_info
        assert rule_info["id"] == "R7"

    def test_multiple_same_category_violations(self, rules):
        """Test multiple violations of the same category."""
        detections = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("NAMES", "Jane Doe", 20, 28, 0.92),
        ]

        explanation = create_violation_explanation(detections, rules)

        assert explanation["num_violations"] == 2
        assert explanation["categories_violated"] == ["NAMES"]

    def test_violation_structure(self, rules):
        """Test the structure of violation explanation."""
        detections = [PHIDetection("PHONE_NUMBERS", "555-1234", 0, 8, 0.9)]

        explanation = create_violation_explanation(detections, rules)

        assert "num_violations" in explanation
        assert "violations" in explanation
        assert "categories_violated" in explanation
        assert isinstance(explanation["num_violations"], int)
        assert isinstance(explanation["violations"], list)
        assert isinstance(explanation["categories_violated"], list)


class TestHIPAARulesCustomConfig:
    """Test HIPAARules with custom config path."""

    def test_default_config_path(self):
        """Test that default config path works."""
        rules = HIPAARules()
        assert rules.config is not None
        assert "categories" in rules.config

    def test_explicit_config_path(self):
        """Test loading with explicit config path."""
        config_path = Path(__file__).parent.parent / "configs" / "hipaa-v1.json"
        rules = HIPAARules(config_path)
        assert rules.config is not None
        assert len(rules.get_prohibited_categories()) == 18

    def test_invalid_config_path(self):
        """Test that invalid config path raises an error."""
        with pytest.raises(FileNotFoundError):
            HIPAARules("/nonexistent/path/config.json")


class TestZ3Integration:
    """Test Z3 solver integration."""

    @pytest.fixture
    def rules(self):
        """Create a HIPAARules instance for testing."""
        return HIPAARules()

    def test_compliant_document(self, rules):
        """Test that compliant document passes Z3 verification."""
        solver = Solver()
        detections = []  # No PHI detected

        category_vars = rules.create_z3_constraints(detections, solver)
        rules.add_compliance_rule(solver, category_vars)

        result = solver.check()
        assert result == sat, "Compliant document should be satisfiable"

    def test_violation_document(self, rules):
        """Test that document with PHI fails Z3 verification."""
        solver = Solver()
        detections = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("SSN", "123-45-6789", 20, 31, 0.99),
        ]

        category_vars = rules.create_z3_constraints(detections, solver)
        rules.add_compliance_rule(solver, category_vars)

        result = solver.check()
        assert result == unsat, "Document with PHI should be unsatisfiable"

    def test_z3_solver_reusability(self, rules):
        """Test that Z3 solver can be reused for multiple checks."""
        solver = Solver()

        # First check - compliant
        detections1 = []
        category_vars1 = rules.create_z3_constraints(detections1, solver)
        rules.add_compliance_rule(solver, category_vars1)
        result1 = solver.check()
        assert result1 == sat

        # Reset solver
        solver.reset()

        # Second check - violation
        detections2 = [PHIDetection("SSN", "123-45-6789", 0, 11, 1.0)]
        category_vars2 = rules.create_z3_constraints(detections2, solver)
        rules.add_compliance_rule(solver, category_vars2)
        result2 = solver.check()
        assert result2 == unsat
