"""Unit tests for PHI extractor module.

Tests the PHIExtractor and MockExtractor classes for entity extraction,
as well as extraction configuration.
"""

import re
import sys
from pathlib import Path

import pytest

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.inference.extractor import ExtractionConfig, MockExtractor, PHIExtractor
from src.verification.rules import PHIDetection


class TestExtractionConfig:
    """Test the ExtractionConfig dataclass."""

    def test_default_config(self):
        """Test default configuration values."""
        config = ExtractionConfig()

        assert config.model_path == "./hipaa_dslm"
        assert config.device == "auto"
        assert config.batch_size == 8
        assert config.max_length == 512
        assert config.confidence_threshold == 0.5

    def test_custom_config(self):
        """Test creating config with custom values."""
        config = ExtractionConfig(
            model_path="/path/to/model",
            device="cpu",
            batch_size=16,
            max_length=256,
            confidence_threshold=0.7
        )

        assert config.model_path == "/path/to/model"
        assert config.device == "cpu"
        assert config.batch_size == 16
        assert config.max_length == 256
        assert config.confidence_threshold == 0.7

    def test_partial_custom_config(self):
        """Test creating config with some custom values."""
        config = ExtractionConfig(
            device="cuda",
            confidence_threshold=0.8
        )

        # Custom values
        assert config.device == "cuda"
        assert config.confidence_threshold == 0.8

        # Default values
        assert config.model_path == "./hipaa_dslm"
        assert config.batch_size == 8
        assert config.max_length == 512


class TestMockExtractor:
    """Test the MockExtractor class."""

    @pytest.fixture
    def extractor(self):
        """Create a MockExtractor instance for testing."""
        return MockExtractor()

    def test_initialization(self, extractor):
        """Test MockExtractor initialization."""
        assert extractor is not None
        assert hasattr(extractor, 'patterns')
        assert hasattr(extractor, 'mapper')

    def test_patterns_exist(self, extractor):
        """Test that regex patterns are defined."""
        expected_patterns = [
            "SSN",
            "PHONE_NUMBERS",
            "EMAIL_ADDRESSES",
            "DATES",
            "IP_ADDRESSES",
            "MEDICAL_RECORD_NUMBERS"
        ]

        for pattern_name in expected_patterns:
            assert pattern_name in extractor.patterns
            assert isinstance(extractor.patterns[pattern_name], re.Pattern)

    def test_extract_ssn(self, extractor):
        """Test extracting Social Security Numbers."""
        text = "Patient SSN is 123-45-6789"
        entities = extractor.extract(text)

        ssn_entities = [e for e in entities if e.category == "SSN"]
        assert len(ssn_entities) == 1
        assert ssn_entities[0].value == "123-45-6789"
        assert ssn_entities[0].start == 15
        assert ssn_entities[0].end == 26
        assert ssn_entities[0].confidence == 0.8

    def test_extract_multiple_ssn(self, extractor):
        """Test extracting multiple SSNs."""
        text = "SSN1: 123-45-6789, SSN2: 987-65-4321"
        entities = extractor.extract(text)

        ssn_entities = [e for e in entities if e.category == "SSN"]
        assert len(ssn_entities) == 2
        assert ssn_entities[0].value == "123-45-6789"
        assert ssn_entities[1].value == "987-65-4321"

    def test_extract_phone_number(self, extractor):
        """Test extracting phone numbers."""
        text = "Call me at 555-123-4567"
        entities = extractor.extract(text)

        phone_entities = [e for e in entities if e.category == "PHONE_NUMBERS"]
        assert len(phone_entities) == 1
        assert phone_entities[0].value == "555-123-4567"

    def test_extract_phone_various_formats(self, extractor):
        """Test extracting phone numbers in various formats."""
        test_cases = [
            ("555-123-4567", "555-123-4567"),
            ("(555) 123-4567", "(555) 123-4567"),
            ("5551234567", "5551234567"),
            ("+1-555-123-4567", "+1-555-123-4567"),
        ]

        for text, expected in test_cases:
            entities = extractor.extract(f"Phone: {text}")
            phone_entities = [e for e in entities if e.category == "PHONE_NUMBERS"]
            assert len(phone_entities) >= 1, f"Failed to extract {text}"

    def test_extract_email(self, extractor):
        """Test extracting email addresses."""
        text = "Contact: john.smith@example.com"
        entities = extractor.extract(text)

        email_entities = [e for e in entities if e.category == "EMAIL_ADDRESSES"]
        assert len(email_entities) == 1
        assert email_entities[0].value == "john.smith@example.com"

    def test_extract_email_various_formats(self, extractor):
        """Test extracting various email formats."""
        emails = [
            "simple@example.com",
            "user.name@example.com",
            "user+tag@example.co.uk",
            "first.last@sub.example.com"
        ]

        for email in emails:
            entities = extractor.extract(f"Email: {email}")
            email_entities = [e for e in entities if e.category == "EMAIL_ADDRESSES"]
            assert len(email_entities) >= 1, f"Failed to extract {email}"
            assert email in email_entities[0].value

    def test_extract_dates(self, extractor):
        """Test extracting dates."""
        text = "Admitted on 01/15/2024"
        entities = extractor.extract(text)

        date_entities = [e for e in entities if e.category == "DATES"]
        assert len(date_entities) == 1
        assert date_entities[0].value == "01/15/2024"

    def test_extract_date_various_formats(self, extractor):
        """Test extracting dates in various formats."""
        dates = [
            "01/15/2024",
            "1/15/2024",
            "01-15-2024",
            "2024-01-15",
            "12/31/99"
        ]

        for date in dates:
            entities = extractor.extract(f"Date: {date}")
            date_entities = [e for e in entities if e.category == "DATES"]
            assert len(date_entities) >= 1, f"Failed to extract {date}"

    def test_extract_ip_address(self, extractor):
        """Test extracting IP addresses."""
        text = "Server IP: 192.168.1.100"
        entities = extractor.extract(text)

        ip_entities = [e for e in entities if e.category == "IP_ADDRESSES"]
        assert len(ip_entities) == 1
        assert ip_entities[0].value == "192.168.1.100"

    def test_extract_medical_record_number(self, extractor):
        """Test extracting medical record numbers."""
        text = "MRN: 123456"
        entities = extractor.extract(text)

        mrn_entities = [e for e in entities if e.category == "MEDICAL_RECORD_NUMBERS"]
        assert len(mrn_entities) == 1
        assert "123456" in mrn_entities[0].value

    def test_extract_mrn_various_formats(self, extractor):
        """Test extracting MRN in various formats."""
        test_cases = [
            "MRN: 123456",
            "MRN #123456",
            "mrn-123456",
            "MRN 123456"
        ]

        for text in test_cases:
            entities = extractor.extract(text)
            mrn_entities = [e for e in entities if e.category == "MEDICAL_RECORD_NUMBERS"]
            assert len(mrn_entities) >= 1, f"Failed to extract from '{text}'"

    def test_extract_no_phi(self, extractor):
        """Test extraction from text with no PHI."""
        text = "The patient was diagnosed with diabetes."
        entities = extractor.extract(text)

        assert len(entities) == 0

    def test_extract_multiple_types(self, extractor):
        """Test extracting multiple PHI types from one text."""
        text = """
        Patient: John Smith
        SSN: 123-45-6789
        Email: john@example.com
        Phone: 555-123-4567
        Admitted: 01/15/2024
        """

        entities = extractor.extract(text)

        # Should find at least SSN, email, phone, and date
        categories = {e.category for e in entities}
        assert "SSN" in categories
        assert "EMAIL_ADDRESSES" in categories
        assert "PHONE_NUMBERS" in categories
        assert "DATES" in categories

    def test_extract_position_accuracy(self, extractor):
        """Test that extraction positions are accurate."""
        text = "SSN: 123-45-6789"
        entities = extractor.extract(text)

        ssn_entities = [e for e in entities if e.category == "SSN"]
        assert len(ssn_entities) == 1

        entity = ssn_entities[0]
        extracted_text = text[entity.start:entity.end]
        assert extracted_text == entity.value

    def test_extract_confidence_fixed(self, extractor):
        """Test that MockExtractor uses fixed confidence."""
        text = "SSN: 123-45-6789"
        entities = extractor.extract(text)

        assert len(entities) == 1
        assert entities[0].confidence == 0.8

    def test_extract_empty_string(self, extractor):
        """Test extraction from empty string."""
        entities = extractor.extract("")
        assert len(entities) == 0

    def test_extract_whitespace_only(self, extractor):
        """Test extraction from whitespace-only string."""
        entities = extractor.extract("   \n\t  ")
        assert len(entities) == 0

    def test_extract_special_characters(self, extractor):
        """Test extraction with special characters."""
        text = "Email: user@example.com!!! Phone: (555) 123-4567."
        entities = extractor.extract(text)

        # Should still extract email and phone despite punctuation
        categories = {e.category for e in entities}
        assert "EMAIL_ADDRESSES" in categories
        assert "PHONE_NUMBERS" in categories

    def test_extract_case_insensitive_mrn(self, extractor):
        """Test that MRN extraction is case-insensitive."""
        test_cases = ["MRN: 123456", "mrn: 123456", "Mrn: 123456"]

        for text in test_cases:
            entities = extractor.extract(text)
            mrn_entities = [e for e in entities if e.category == "MEDICAL_RECORD_NUMBERS"]
            assert len(mrn_entities) >= 1, f"Failed for '{text}'"


class TestPHIExtractor:
    """Test the PHIExtractor class (without loading actual model)."""

    def test_initialization_default_config(self):
        """Test PHIExtractor initialization with default config."""
        extractor = PHIExtractor()

        assert extractor.config is not None
        assert extractor.config.model_path == "./hipaa_dslm"
        assert extractor.mapper is not None
        assert extractor.model is None
        assert extractor.tokenizer is None
        assert extractor.ner_pipeline is None
        assert extractor._loaded is False

    def test_initialization_custom_config(self):
        """Test PHIExtractor initialization with custom config."""
        config = ExtractionConfig(
            model_path="/custom/path",
            device="cpu",
            confidence_threshold=0.7
        )
        extractor = PHIExtractor(config)

        assert extractor.config.model_path == "/custom/path"
        assert extractor.config.device == "cpu"
        assert extractor.config.confidence_threshold == 0.7

    def test_not_loaded_initially(self):
        """Test that extractor is not loaded on initialization."""
        extractor = PHIExtractor()

        assert not extractor._loaded
        assert extractor.model is None
        assert extractor.tokenizer is None

    def test_load_model_nonexistent_path(self):
        """Test loading model from non-existent path raises error."""
        config = ExtractionConfig(model_path="/nonexistent/path")
        extractor = PHIExtractor(config)

        with pytest.raises(FileNotFoundError) as exc_info:
            extractor.load_model()

        assert "Model not found" in str(exc_info.value)
        assert "/nonexistent/path" in str(exc_info.value)

    def test_to_json_empty(self):
        """Test converting empty entity list to JSON."""
        extractor = PHIExtractor()
        entities = []

        result = extractor.to_json(entities)

        assert "entities" in result
        assert result["entities"] == []

    def test_to_json_with_entities(self):
        """Test converting entities to JSON."""
        extractor = PHIExtractor()
        entities = [
            PHIDetection("NAMES", "John", 0, 4, 0.95),
            PHIDetection("SSN", "123-45-6789", 10, 21, 0.99)
        ]

        result = extractor.to_json(entities)

        assert "entities" in result
        assert len(result["entities"]) == 2

        assert result["entities"][0]["category"] == "NAMES"
        assert result["entities"][0]["value"] == "John"
        assert result["entities"][0]["start"] == 0
        assert result["entities"][0]["end"] == 4
        assert result["entities"][0]["confidence"] == 0.95

        assert result["entities"][1]["category"] == "SSN"
        assert result["entities"][1]["value"] == "123-45-6789"

    def test_has_label_mapper(self):
        """Test that PHIExtractor has label mapper."""
        extractor = PHIExtractor()
        assert extractor.mapper is not None
        assert hasattr(extractor.mapper, 'label2id')
        assert hasattr(extractor.mapper, 'id2label')


class TestMockExtractorEdgeCases:
    """Test edge cases for MockExtractor."""

    @pytest.fixture
    def extractor(self):
        """Create a MockExtractor instance for testing."""
        return MockExtractor()

    def test_overlapping_matches(self, extractor):
        """Test behavior with overlapping pattern matches."""
        # A string that might match multiple patterns
        text = "123-45-6789"  # Could be SSN
        entities = extractor.extract(text)

        # Should be detected as SSN
        ssn_entities = [e for e in entities if e.category == "SSN"]
        assert len(ssn_entities) >= 1

    def test_very_long_text(self, extractor):
        """Test extraction from very long text."""
        text = "Clean text. " * 1000 + "SSN: 123-45-6789"
        entities = extractor.extract(text)

        ssn_entities = [e for e in entities if e.category == "SSN"]
        assert len(ssn_entities) == 1

    def test_unicode_text(self, extractor):
        """Test extraction with unicode characters."""
        text = "Email: user@example.com ñáëü"
        entities = extractor.extract(text)

        email_entities = [e for e in entities if e.category == "EMAIL_ADDRESSES"]
        assert len(email_entities) >= 1

    def test_multiple_spaces(self, extractor):
        """Test extraction with multiple spaces."""
        text = "SSN:     123-45-6789"
        entities = extractor.extract(text)

        # MRN pattern might not match this, but SSN should
        ssn_entities = [e for e in entities if e.category == "SSN"]
        assert len(ssn_entities) >= 1

    def test_line_breaks(self, extractor):
        """Test extraction with line breaks."""
        text = "SSN:\n123-45-6789\nEmail:\nuser@example.com"
        entities = extractor.extract(text)

        ssn_entities = [e for e in entities if e.category == "SSN"]
        email_entities = [e for e in entities if e.category == "EMAIL_ADDRESSES"]

        assert len(ssn_entities) >= 1
        assert len(email_entities) >= 1

    def test_tabs(self, extractor):
        """Test extraction with tab characters."""
        text = "SSN:\t123-45-6789\tPhone:\t555-123-4567"
        entities = extractor.extract(text)

        ssn_entities = [e for e in entities if e.category == "SSN"]
        phone_entities = [e for e in entities if e.category == "PHONE_NUMBERS"]

        assert len(ssn_entities) >= 1
        assert len(phone_entities) >= 1


class TestMockExtractorIntegration:
    """Integration tests for MockExtractor with verifier."""

    @pytest.fixture
    def extractor(self):
        """Create a MockExtractor instance for testing."""
        return MockExtractor()

    def test_extractor_output_compatible_with_verifier(self, extractor):
        """Test that extractor output can be used by verifier."""
        # This test ensures the PHIDetection objects are created correctly
        text = "Patient SSN: 123-45-6789, Email: john@example.com"
        entities = extractor.extract(text)

        # Check that entities are PHIDetection instances
        for entity in entities:
            assert isinstance(entity, PHIDetection)
            assert hasattr(entity, 'category')
            assert hasattr(entity, 'value')
            assert hasattr(entity, 'start')
            assert hasattr(entity, 'end')
            assert hasattr(entity, 'confidence')

    def test_extractor_with_real_medical_text(self, extractor):
        """Test extraction from realistic medical text."""
        text = """
        PATIENT INFORMATION
        Name: John Smith
        MRN: 123456
        Date of Birth: 01/15/1980
        Phone: (555) 123-4567
        Email: john.smith@email.com
        SSN: 123-45-6789

        CLINICAL NOTES
        Patient was admitted on 03/20/2024 with symptoms of...
        """

        entities = extractor.extract(text)

        # Should detect multiple PHI elements
        categories = {e.category for e in entities}

        # Check for expected categories
        assert "SSN" in categories
        assert "PHONE_NUMBERS" in categories
        assert "EMAIL_ADDRESSES" in categories
        assert "DATES" in categories
        assert "MEDICAL_RECORD_NUMBERS" in categories

    def test_extractor_returns_sorted_positions(self, extractor):
        """Test that extractor returns entities with valid positions."""
        text = "SSN: 123-45-6789, Phone: 555-123-4567"
        entities = extractor.extract(text)

        for entity in entities:
            # Positions should be valid
            assert entity.start >= 0
            assert entity.end > entity.start
            assert entity.end <= len(text)

            # Value should match the text at that position
            extracted = text[entity.start:entity.end]
            assert extracted == entity.value
