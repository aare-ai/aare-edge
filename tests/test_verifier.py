"""Unit tests for HIPAA verifier module.

Tests the HIPAAVerifier class, VerificationResult, and verification functions
for formal Z3-based HIPAA compliance checking.
"""

import json
import sys
from pathlib import Path

import pytest
from z3 import Solver

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.verification.rules import PHIDetection
from src.verification.verifier import (
    ComplianceStatus,
    HIPAAVerifier,
    VerificationResult,
    verify_from_json,
)


class TestComplianceStatus:
    """Test the ComplianceStatus enum."""

    def test_compliance_status_values(self):
        """Test that ComplianceStatus has expected values."""
        assert ComplianceStatus.COMPLIANT.value == "compliant"
        assert ComplianceStatus.VIOLATION.value == "violation"
        assert ComplianceStatus.ERROR.value == "error"

    def test_compliance_status_membership(self):
        """Test ComplianceStatus enum membership."""
        assert ComplianceStatus.COMPLIANT in ComplianceStatus
        assert ComplianceStatus.VIOLATION in ComplianceStatus
        assert ComplianceStatus.ERROR in ComplianceStatus


class TestVerificationResult:
    """Test the VerificationResult dataclass."""

    def test_verification_result_creation(self):
        """Test creating a VerificationResult instance."""
        entities = [PHIDetection("NAMES", "John", 0, 4, 0.9)]
        result = VerificationResult(
            status=ComplianceStatus.VIOLATION,
            entities=entities,
            proof="Test proof",
            violations={"num_violations": 1},
            metadata={"test": "data"}
        )

        assert result.status == ComplianceStatus.VIOLATION
        assert result.entities == entities
        assert result.proof == "Test proof"
        assert result.violations == {"num_violations": 1}
        assert result.metadata == {"test": "data"}

    def test_verification_result_default_metadata(self):
        """Test that metadata defaults to empty dict."""
        result = VerificationResult(
            status=ComplianceStatus.COMPLIANT,
            entities=[],
            proof="Compliant",
            violations=None
        )

        assert result.metadata == {}

    def test_to_dict_compliant(self):
        """Test converting compliant result to dictionary."""
        result = VerificationResult(
            status=ComplianceStatus.COMPLIANT,
            entities=[],
            proof="Document is compliant",
            violations=None,
            metadata={"solver_result": "sat"}
        )

        result_dict = result.to_dict()

        assert result_dict["status"] == "compliant"
        assert result_dict["entities"] == []
        assert result_dict["proof"] == "Document is compliant"
        assert result_dict["violations"] is None
        assert result_dict["metadata"]["solver_result"] == "sat"

    def test_to_dict_violation(self):
        """Test converting violation result to dictionary."""
        entities = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("SSN", "123-45-6789", 20, 31, 0.99)
        ]

        violations = {
            "num_violations": 2,
            "violations": [],
            "categories_violated": ["NAMES", "SSN"]
        }

        result = VerificationResult(
            status=ComplianceStatus.VIOLATION,
            entities=entities,
            proof="Violations detected",
            violations=violations,
            metadata={"solver_result": "unsat"}
        )

        result_dict = result.to_dict()

        assert result_dict["status"] == "violation"
        assert len(result_dict["entities"]) == 2
        assert result_dict["entities"][0]["category"] == "NAMES"
        assert result_dict["entities"][0]["value"] == "John Smith"
        assert result_dict["entities"][1]["category"] == "SSN"
        assert result_dict["violations"]["num_violations"] == 2

    def test_to_dict_entity_structure(self):
        """Test entity structure in dictionary."""
        entity = PHIDetection("EMAIL_ADDRESSES", "test@example.com", 10, 26, 0.88)
        result = VerificationResult(
            status=ComplianceStatus.VIOLATION,
            entities=[entity],
            proof="Test",
            violations=None
        )

        result_dict = result.to_dict()
        entity_dict = result_dict["entities"][0]

        assert entity_dict["category"] == "EMAIL_ADDRESSES"
        assert entity_dict["value"] == "test@example.com"
        assert entity_dict["start"] == 10
        assert entity_dict["end"] == 26
        assert entity_dict["confidence"] == 0.88

    def test_to_json(self):
        """Test converting result to JSON string."""
        result = VerificationResult(
            status=ComplianceStatus.COMPLIANT,
            entities=[],
            proof="Test proof",
            violations=None,
            metadata={"key": "value"}
        )

        json_str = result.to_json()

        assert isinstance(json_str, str)
        parsed = json.loads(json_str)
        assert parsed["status"] == "compliant"
        assert parsed["proof"] == "Test proof"
        assert parsed["metadata"]["key"] == "value"

    def test_to_json_formatting(self):
        """Test that JSON output is formatted with indentation."""
        result = VerificationResult(
            status=ComplianceStatus.COMPLIANT,
            entities=[],
            proof="Test",
            violations=None
        )

        json_str = result.to_json()

        # Check that it's indented (contains newlines)
        assert "\n" in json_str
        assert "  " in json_str  # 2-space indentation


class TestHIPAAVerifier:
    """Test the HIPAAVerifier class."""

    @pytest.fixture
    def verifier(self):
        """Create a HIPAAVerifier instance for testing."""
        return HIPAAVerifier()

    def test_initialization(self, verifier):
        """Test HIPAAVerifier initialization."""
        assert verifier is not None
        assert hasattr(verifier, 'rules')
        assert verifier.rules is not None

    def test_initialization_with_config(self):
        """Test initialization with custom config path."""
        config_path = Path(__file__).parent.parent / "configs" / "hipaa-v1.json"
        verifier = HIPAAVerifier(config_path)
        assert verifier.rules is not None

    def test_verify_compliant_no_phi(self, verifier):
        """Test verification of compliant document with no PHI."""
        entities = []
        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.COMPLIANT
        assert result.entities == []
        assert result.violations is None
        assert "COMPLIANT" in result.proof
        assert result.metadata["solver_result"] == "sat"

    def test_verify_compliant_proof_content(self, verifier):
        """Test that compliant proof contains expected information."""
        result = verifier.verify([])

        assert "HIPAA COMPLIANT" in result.proof
        assert "No prohibited PHI identifiers detected" in result.proof
        assert "18 HIPAA Safe Harbor categories" in result.proof

    def test_verify_violation_single_phi(self, verifier):
        """Test verification with a single PHI violation."""
        entities = [PHIDetection("NAMES", "John Smith", 0, 10, 0.95)]
        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 1
        assert result.violations is not None
        assert result.violations["num_violations"] == 1
        assert "NAMES" in result.violations["categories_violated"]
        assert result.metadata["solver_result"] == "unsat"

    def test_verify_violation_multiple_phi(self, verifier):
        """Test verification with multiple PHI violations."""
        entities = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("SSN", "123-45-6789", 20, 31, 0.99),
            PHIDetection("EMAIL_ADDRESSES", "john@example.com", 40, 56, 0.88),
        ]

        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 3
        assert result.violations["num_violations"] == 3
        assert set(result.violations["categories_violated"]) == {
            "NAMES", "SSN", "EMAIL_ADDRESSES"
        }

    def test_verify_violation_proof_content(self, verifier):
        """Test that violation proof contains expected information."""
        entities = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("SSN", "123-45-6789", 20, 31, 0.99),
        ]

        result = verifier.verify(entities)

        assert "HIPAA VIOLATION DETECTED" in result.proof
        assert "NAMES" in result.proof
        assert "SSN" in result.proof
        assert "John Smith" in result.proof
        assert "123-45-6789" in result.proof
        assert "Total violations: 2" in result.proof

    def test_verify_all_18_categories(self, verifier):
        """Test verification with all 18 HIPAA categories."""
        entities = [
            PHIDetection("NAMES", "John", 0, 4, 1.0),
            PHIDetection("GEOGRAPHIC_SUBDIVISIONS", "Boston", 5, 11, 1.0),
            PHIDetection("DATES", "01/15/2024", 12, 22, 1.0),
            PHIDetection("PHONE_NUMBERS", "555-1234", 23, 31, 1.0),
            PHIDetection("FAX_NUMBERS", "555-5678", 32, 40, 1.0),
            PHIDetection("EMAIL_ADDRESSES", "test@example.com", 41, 57, 1.0),
            PHIDetection("SSN", "123-45-6789", 58, 69, 1.0),
            PHIDetection("MEDICAL_RECORD_NUMBERS", "MRN123", 70, 76, 1.0),
            PHIDetection("HEALTH_PLAN_BENEFICIARY_NUMBERS", "HPN456", 77, 83, 1.0),
            PHIDetection("ACCOUNT_NUMBERS", "ACC789", 84, 90, 1.0),
            PHIDetection("CERTIFICATE_LICENSE_NUMBERS", "LIC001", 91, 97, 1.0),
            PHIDetection("VEHICLE_IDENTIFIERS", "VIN123", 98, 104, 1.0),
            PHIDetection("DEVICE_IDENTIFIERS", "DEV456", 105, 111, 1.0),
            PHIDetection("WEB_URLS", "http://example.com", 112, 130, 1.0),
            PHIDetection("IP_ADDRESSES", "192.168.1.1", 131, 142, 1.0),
            PHIDetection("BIOMETRIC_IDENTIFIERS", "FP123", 143, 148, 1.0),
            PHIDetection("PHOTOGRAPHIC_IMAGES", "photo.jpg", 149, 158, 1.0),
            PHIDetection("ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER", "ID999", 159, 164, 1.0),
        ]

        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.VIOLATION
        assert result.violations["num_violations"] == 18
        assert len(result.violations["categories_violated"]) == 18

    def test_verify_same_category_multiple_times(self, verifier):
        """Test verification with multiple instances of same category."""
        entities = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
            PHIDetection("NAMES", "Jane Doe", 20, 28, 0.92),
            PHIDetection("NAMES", "Bob Johnson", 40, 51, 0.88),
        ]

        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.VIOLATION
        assert result.violations["num_violations"] == 3
        assert result.violations["categories_violated"] == ["NAMES"]

    def test_verify_text_no_extractor(self, verifier):
        """Test verify_text without providing an extractor."""
        result = verifier.verify_text("Test document")

        assert result.status == ComplianceStatus.ERROR
        assert result.entities == []
        assert "No entity extractor provided" in result.proof
        assert result.metadata["error"] == "no_extractor"

    def test_verify_text_with_extractor(self, verifier):
        """Test verify_text with a mock extractor."""
        def mock_extractor(text):
            return [PHIDetection("NAMES", "John", 0, 4, 0.9)]

        result = verifier.verify_text("John went to the store", mock_extractor)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 1
        assert result.entities[0].category == "NAMES"

    def test_verify_text_with_extractor_compliant(self, verifier):
        """Test verify_text with extractor returning no PHI."""
        def mock_extractor(text):
            return []

        result = verifier.verify_text("This is clean text", mock_extractor)

        assert result.status == ComplianceStatus.COMPLIANT
        assert result.entities == []

    def test_verify_text_extractor_exception(self, verifier):
        """Test verify_text when extractor raises exception."""
        def failing_extractor(text):
            raise ValueError("Extraction failed")

        result = verifier.verify_text("Test text", failing_extractor)

        assert result.status == ComplianceStatus.ERROR
        assert "Error during verification" in result.proof
        assert "Extraction failed" in result.metadata["error"]

    def test_batch_verify_empty(self, verifier):
        """Test batch verification with empty list."""
        results = verifier.batch_verify([])
        assert results == []

    def test_batch_verify_single(self, verifier):
        """Test batch verification with single document."""
        documents = [[PHIDetection("NAMES", "John", 0, 4, 0.9)]]
        results = verifier.batch_verify(documents)

        assert len(results) == 1
        assert results[0].status == ComplianceStatus.VIOLATION

    def test_batch_verify_multiple(self, verifier):
        """Test batch verification with multiple documents."""
        documents = [
            [],  # Compliant
            [PHIDetection("NAMES", "John", 0, 4, 0.9)],  # Violation
            [PHIDetection("SSN", "123-45-6789", 0, 11, 1.0)],  # Violation
            [],  # Compliant
        ]

        results = verifier.batch_verify(documents)

        assert len(results) == 4
        assert results[0].status == ComplianceStatus.COMPLIANT
        assert results[1].status == ComplianceStatus.VIOLATION
        assert results[2].status == ComplianceStatus.VIOLATION
        assert results[3].status == ComplianceStatus.COMPLIANT

    def test_batch_verify_independence(self, verifier):
        """Test that batch verification results are independent."""
        documents = [
            [PHIDetection("NAMES", "John", 0, 4, 0.9)],
            [],
        ]

        results = verifier.batch_verify(documents)

        # First document has violation, second doesn't
        assert results[0].status == ComplianceStatus.VIOLATION
        assert results[1].status == ComplianceStatus.COMPLIANT

    def test_violation_contains_rule_information(self, verifier):
        """Test that violations include rule information."""
        entities = [PHIDetection("SSN", "123-45-6789", 0, 11, 1.0)]
        result = verifier.verify(entities)

        violation = result.violations["violations"][0]
        assert "violated_rules" in violation
        assert len(violation["violated_rules"]) > 0

        rule = violation["violated_rules"][0]
        assert "id" in rule
        assert "name" in rule
        assert "description" in rule
        assert rule["id"] == "R7"
        assert "Social Security" in rule["description"]


class TestVerifyFromJson:
    """Test the verify_from_json function."""

    def test_verify_from_json_string(self):
        """Test verification from JSON string."""
        json_str = json.dumps({
            "entities": [
                {
                    "category": "NAMES",
                    "value": "John Smith",
                    "start": 0,
                    "end": 10,
                    "confidence": 0.95
                }
            ]
        })

        result = verify_from_json(json_str)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 1
        assert result.entities[0].category == "NAMES"

    def test_verify_from_json_dict(self):
        """Test verification from dictionary."""
        json_dict = {
            "entities": [
                {
                    "category": "SSN",
                    "value": "123-45-6789",
                    "start": 0,
                    "end": 11,
                    "confidence": 0.99
                }
            ]
        }

        result = verify_from_json(json_dict)

        assert result.status == ComplianceStatus.VIOLATION
        assert result.entities[0].category == "SSN"
        assert result.entities[0].value == "123-45-6789"

    def test_verify_from_json_no_entities(self):
        """Test verification with no entities in JSON."""
        json_dict = {"entities": []}

        result = verify_from_json(json_dict)

        assert result.status == ComplianceStatus.COMPLIANT
        assert len(result.entities) == 0

    def test_verify_from_json_direct_list(self):
        """Test verification when JSON is a direct list of entities."""
        json_list = [
            {
                "category": "EMAIL_ADDRESSES",
                "value": "test@example.com",
                "start": 0,
                "end": 16,
                "confidence": 0.88
            }
        ]

        result = verify_from_json(json_list)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 1

    def test_verify_from_json_missing_fields(self):
        """Test verification with missing optional fields."""
        json_dict = {
            "entities": [
                {
                    "category": "NAMES",
                    # Missing value, start, end, confidence
                }
            ]
        }

        result = verify_from_json(json_dict)

        # Should use defaults
        assert result.entities[0].value == ""
        assert result.entities[0].start == 0
        assert result.entities[0].end == 0
        assert result.entities[0].confidence == 1.0

    def test_verify_from_json_with_config(self):
        """Test verification with custom config path."""
        config_path = Path(__file__).parent.parent / "configs" / "hipaa-v1.json"
        json_dict = {"entities": []}

        result = verify_from_json(json_dict, config_path)

        assert result.status == ComplianceStatus.COMPLIANT

    def test_verify_from_json_multiple_entities(self):
        """Test verification with multiple entities."""
        json_dict = {
            "entities": [
                {"category": "NAMES", "value": "John", "start": 0, "end": 4},
                {"category": "SSN", "value": "123-45-6789", "start": 10, "end": 21},
                {"category": "DATES", "value": "01/15/2024", "start": 30, "end": 40},
            ]
        }

        result = verify_from_json(json_dict)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 3
        assert result.violations["num_violations"] == 3


class TestVerificationResultSerialization:
    """Test VerificationResult serialization and deserialization."""

    def test_round_trip_compliant(self):
        """Test serializing and deserializing compliant result."""
        original = VerificationResult(
            status=ComplianceStatus.COMPLIANT,
            entities=[],
            proof="Document is compliant",
            violations=None,
            metadata={"test": "data"}
        )

        # Convert to JSON and back
        json_str = original.to_json()
        parsed = json.loads(json_str)

        assert parsed["status"] == "compliant"
        assert parsed["entities"] == []
        assert parsed["proof"] == "Document is compliant"
        assert parsed["violations"] is None
        assert parsed["metadata"]["test"] == "data"

    def test_round_trip_violation(self):
        """Test serializing and deserializing violation result."""
        entities = [
            PHIDetection("NAMES", "John", 0, 4, 0.9),
            PHIDetection("SSN", "123-45-6789", 10, 21, 0.99)
        ]

        original = VerificationResult(
            status=ComplianceStatus.VIOLATION,
            entities=entities,
            proof="Violations found",
            violations={"num_violations": 2},
            metadata={"solver_result": "unsat"}
        )

        # Convert to JSON and back
        json_str = original.to_json()
        parsed = json.loads(json_str)

        assert parsed["status"] == "violation"
        assert len(parsed["entities"]) == 2
        assert parsed["entities"][0]["category"] == "NAMES"
        assert parsed["violations"]["num_violations"] == 2

    def test_json_valid_format(self):
        """Test that JSON output is valid and parseable."""
        result = VerificationResult(
            status=ComplianceStatus.COMPLIANT,
            entities=[],
            proof="Test",
            violations=None
        )

        json_str = result.to_json()

        # Should not raise exception
        parsed = json.loads(json_str)
        assert isinstance(parsed, dict)


class TestEdgeCases:
    """Test edge cases and boundary conditions."""

    @pytest.fixture
    def verifier(self):
        """Create a HIPAAVerifier instance for testing."""
        return HIPAAVerifier()

    def test_verify_empty_entity_list(self, verifier):
        """Test verification with explicitly empty entity list."""
        result = verifier.verify([])
        assert result.status == ComplianceStatus.COMPLIANT

    def test_verify_very_low_confidence(self, verifier):
        """Test verification with very low confidence detection."""
        entities = [PHIDetection("NAMES", "Maybe", 0, 5, 0.01)]
        result = verifier.verify(entities)

        # Should still be a violation regardless of confidence
        assert result.status == ComplianceStatus.VIOLATION

    def test_verify_high_confidence(self, verifier):
        """Test verification with perfect confidence."""
        entities = [PHIDetection("SSN", "123-45-6789", 0, 11, 1.0)]
        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.VIOLATION
        assert result.entities[0].confidence == 1.0

    def test_verify_large_number_of_entities(self, verifier):
        """Test verification with many entities."""
        entities = [
            PHIDetection("NAMES", f"Person{i}", i * 10, i * 10 + 8, 0.9)
            for i in range(100)
        ]

        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 100

    def test_verify_overlapping_detections(self, verifier):
        """Test verification with overlapping entity positions."""
        entities = [
            PHIDetection("NAMES", "John Smith", 0, 10, 0.9),
            PHIDetection("NAMES", "Smith", 5, 10, 0.85),
        ]

        result = verifier.verify(entities)

        assert result.status == ComplianceStatus.VIOLATION
        assert len(result.entities) == 2
