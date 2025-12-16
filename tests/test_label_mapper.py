"""Unit tests for label mapping module.

Tests the LabelMapper class and related functions for converting between
dataset-specific labels and HIPAA Safe Harbor categories.
"""

import json
import sys
from pathlib import Path

import pytest

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.data.label_mapper import LabelMapper, load_hipaa_config


class TestLoadHipaaConfig:
    """Test the load_hipaa_config function."""

    def test_load_default_config(self):
        """Test loading config with default path."""
        config = load_hipaa_config()

        assert config is not None
        assert isinstance(config, dict)
        assert "categories" in config
        assert "label_list" in config
        assert "num_labels" in config
        assert "dataset_label_remap" in config

    def test_load_explicit_config(self):
        """Test loading config with explicit path."""
        config_path = Path(__file__).parent.parent / "configs" / "hipaa-v1.json"
        config = load_hipaa_config(config_path)

        assert config is not None
        assert "version" in config
        assert config["version"] == "1.0.0"

    def test_load_config_as_string(self):
        """Test loading config with path as string."""
        config_path = str(Path(__file__).parent.parent / "configs" / "hipaa-v1.json")
        config = load_hipaa_config(config_path)

        assert config is not None
        assert "categories" in config

    def test_config_structure(self):
        """Test that loaded config has expected structure."""
        config = load_hipaa_config()

        # Check top-level keys
        assert "version" in config
        assert "name" in config
        assert "description" in config
        assert "categories" in config
        assert "label_list" in config
        assert "num_labels" in config
        assert "dataset_label_remap" in config

        # Check categories structure
        assert isinstance(config["categories"], list)
        assert len(config["categories"]) == 18

        # Check label list
        assert isinstance(config["label_list"], list)
        assert len(config["label_list"]) == 37  # 1 O + 18 * 2 (B- and I-)

    def test_invalid_config_path(self):
        """Test that invalid config path raises error."""
        with pytest.raises(FileNotFoundError):
            load_hipaa_config("/nonexistent/path/config.json")


class TestLabelMapper:
    """Test the LabelMapper class."""

    @pytest.fixture
    def mapper(self):
        """Create a LabelMapper instance for testing."""
        return LabelMapper()

    def test_initialization(self, mapper):
        """Test LabelMapper initialization."""
        assert mapper is not None
        assert hasattr(mapper, 'config')
        assert hasattr(mapper, 'label_list')
        assert hasattr(mapper, 'num_labels')
        assert hasattr(mapper, 'remap')
        assert hasattr(mapper, 'label2id')
        assert hasattr(mapper, 'id2label')
        assert hasattr(mapper, 'categories')
        assert hasattr(mapper, 'prohibited_categories')

    def test_num_labels(self, mapper):
        """Test that num_labels is correct."""
        assert mapper.num_labels == 37

    def test_label_list_length(self, mapper):
        """Test that label_list has correct length."""
        assert len(mapper.label_list) == 37

    def test_label_list_starts_with_o(self, mapper):
        """Test that label list starts with 'O'."""
        assert mapper.label_list[0] == "O"

    def test_all_labels_present(self, mapper):
        """Test that all 37 BIO labels are present."""
        expected_labels = [
            "O",
            "B-NAMES", "I-NAMES",
            "B-GEOGRAPHIC_SUBDIVISIONS", "I-GEOGRAPHIC_SUBDIVISIONS",
            "B-DATES", "I-DATES",
            "B-PHONE_NUMBERS", "I-PHONE_NUMBERS",
            "B-FAX_NUMBERS", "I-FAX_NUMBERS",
            "B-EMAIL_ADDRESSES", "I-EMAIL_ADDRESSES",
            "B-SSN", "I-SSN",
            "B-MEDICAL_RECORD_NUMBERS", "I-MEDICAL_RECORD_NUMBERS",
            "B-HEALTH_PLAN_BENEFICIARY_NUMBERS", "I-HEALTH_PLAN_BENEFICIARY_NUMBERS",
            "B-ACCOUNT_NUMBERS", "I-ACCOUNT_NUMBERS",
            "B-CERTIFICATE_LICENSE_NUMBERS", "I-CERTIFICATE_LICENSE_NUMBERS",
            "B-VEHICLE_IDENTIFIERS", "I-VEHICLE_IDENTIFIERS",
            "B-DEVICE_IDENTIFIERS", "I-DEVICE_IDENTIFIERS",
            "B-WEB_URLS", "I-WEB_URLS",
            "B-IP_ADDRESSES", "I-IP_ADDRESSES",
            "B-BIOMETRIC_IDENTIFIERS", "I-BIOMETRIC_IDENTIFIERS",
            "B-PHOTOGRAPHIC_IMAGES", "I-PHOTOGRAPHIC_IMAGES",
            "B-ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER", "I-ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"
        ]

        assert mapper.label_list == expected_labels

    def test_label2id_mapping(self, mapper):
        """Test label2id mapping."""
        assert mapper.label2id["O"] == 0
        assert mapper.label2id["B-NAMES"] == 1
        assert mapper.label2id["I-NAMES"] == 2
        assert mapper.label2id["B-SSN"] == 13
        assert mapper.label2id["I-SSN"] == 14

    def test_id2label_mapping(self, mapper):
        """Test id2label mapping."""
        assert mapper.id2label[0] == "O"
        assert mapper.id2label[1] == "B-NAMES"
        assert mapper.id2label[2] == "I-NAMES"
        assert mapper.id2label[13] == "B-SSN"
        assert mapper.id2label[14] == "I-SSN"

    def test_label2id_id2label_consistency(self, mapper):
        """Test that label2id and id2label are inverses."""
        for label, label_id in mapper.label2id.items():
            assert mapper.id2label[label_id] == label

        for label_id, label in mapper.id2label.items():
            assert mapper.label2id[label] == label_id

    def test_categories(self, mapper):
        """Test categories list."""
        assert len(mapper.categories) == 18
        assert "NAMES" in mapper.categories
        assert "SSN" in mapper.categories
        assert "EMAIL_ADDRESSES" in mapper.categories

    def test_prohibited_categories(self, mapper):
        """Test prohibited_categories list."""
        assert len(mapper.prohibited_categories) == 18

        # All 18 should be prohibited
        expected_prohibited = [
            "NAMES", "GEOGRAPHIC_SUBDIVISIONS", "DATES", "PHONE_NUMBERS",
            "FAX_NUMBERS", "EMAIL_ADDRESSES", "SSN", "MEDICAL_RECORD_NUMBERS",
            "HEALTH_PLAN_BENEFICIARY_NUMBERS", "ACCOUNT_NUMBERS",
            "CERTIFICATE_LICENSE_NUMBERS", "VEHICLE_IDENTIFIERS",
            "DEVICE_IDENTIFIERS", "WEB_URLS", "IP_ADDRESSES",
            "BIOMETRIC_IDENTIFIERS", "PHOTOGRAPHIC_IMAGES",
            "ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"
        ]

        for category in expected_prohibited:
            assert category in mapper.prohibited_categories


class TestRemapLabel:
    """Test the remap_label method."""

    @pytest.fixture
    def mapper(self):
        """Create a LabelMapper instance for testing."""
        return LabelMapper()

    def test_remap_o_label(self, mapper):
        """Test remapping 'O' label."""
        assert mapper.remap_label("O") == "O"

    def test_remap_patient_to_names(self, mapper):
        """Test remapping PATIENT to NAMES."""
        assert mapper.remap_label("B-PATIENT") == "B-NAMES"
        assert mapper.remap_label("I-PATIENT") == "I-NAMES"

    def test_remap_doctor_to_names(self, mapper):
        """Test remapping DOCTOR to NAMES."""
        assert mapper.remap_label("B-DOCTOR") == "B-NAMES"
        assert mapper.remap_label("I-DOCTOR") == "I-NAMES"

    def test_remap_date_to_dates(self, mapper):
        """Test remapping DATE to DATES."""
        assert mapper.remap_label("B-DATE") == "B-DATES"
        assert mapper.remap_label("I-DATE") == "I-DATES"

    def test_remap_location_to_geographic(self, mapper):
        """Test remapping LOCATION to GEOGRAPHIC_SUBDIVISIONS."""
        assert mapper.remap_label("B-LOCATION") == "B-GEOGRAPHIC_SUBDIVISIONS"
        assert mapper.remap_label("I-LOCATION") == "I-GEOGRAPHIC_SUBDIVISIONS"

    def test_remap_phone_to_phone_numbers(self, mapper):
        """Test remapping PHONE to PHONE_NUMBERS."""
        assert mapper.remap_label("B-PHONE") == "B-PHONE_NUMBERS"
        assert mapper.remap_label("I-PHONE") == "I-PHONE_NUMBERS"

    def test_remap_email_to_email_addresses(self, mapper):
        """Test remapping EMAIL to EMAIL_ADDRESSES."""
        assert mapper.remap_label("B-EMAIL") == "B-EMAIL_ADDRESSES"
        assert mapper.remap_label("I-EMAIL") == "I-EMAIL_ADDRESSES"

    def test_remap_ssn(self, mapper):
        """Test remapping SSN (should stay the same)."""
        assert mapper.remap_label("B-SSN") == "B-SSN"
        assert mapper.remap_label("I-SSN") == "I-SSN"

    def test_remap_medicalrecord_to_medical_record_numbers(self, mapper):
        """Test remapping MEDICALRECORD to MEDICAL_RECORD_NUMBERS."""
        assert mapper.remap_label("B-MEDICALRECORD") == "B-MEDICAL_RECORD_NUMBERS"
        assert mapper.remap_label("I-MEDICALRECORD") == "I-MEDICAL_RECORD_NUMBERS"

    def test_remap_idnum_to_medical_record_numbers(self, mapper):
        """Test remapping IDNUM to MEDICAL_RECORD_NUMBERS."""
        assert mapper.remap_label("B-IDNUM") == "B-MEDICAL_RECORD_NUMBERS"
        assert mapper.remap_label("I-IDNUM") == "I-MEDICAL_RECORD_NUMBERS"

    def test_remap_url_to_web_urls(self, mapper):
        """Test remapping URL to WEB_URLS."""
        assert mapper.remap_label("B-URL") == "B-WEB_URLS"
        assert mapper.remap_label("I-URL") == "I-WEB_URLS"

    def test_remap_ipaddr_to_ip_addresses(self, mapper):
        """Test remapping IPADDR to IP_ADDRESSES."""
        assert mapper.remap_label("B-IPADDR") == "B-IP_ADDRESSES"
        assert mapper.remap_label("I-IPADDR") == "I-IP_ADDRESSES"

    def test_remap_unknown_to_any_other(self, mapper):
        """Test remapping unknown label to ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER."""
        assert mapper.remap_label("B-UNKNOWN") == "B-ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"
        assert mapper.remap_label("I-UNKNOWN") == "I-ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"

    def test_remap_profession_to_any_other(self, mapper):
        """Test remapping PROFESSION to ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER."""
        assert mapper.remap_label("B-PROFESSION") == "B-ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"
        assert mapper.remap_label("I-PROFESSION") == "I-ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"

    def test_remap_without_bio_prefix(self, mapper):
        """Test remapping label without BIO prefix (assumes B-)."""
        assert mapper.remap_label("PATIENT") == "B-NAMES"
        assert mapper.remap_label("DATE") == "B-DATES"

    def test_remap_preserves_bio_prefix(self, mapper):
        """Test that remapping preserves B- vs I- prefix."""
        # B- prefix preserved
        result_b = mapper.remap_label("B-PATIENT")
        assert result_b.startswith("B-")

        # I- prefix preserved
        result_i = mapper.remap_label("I-PATIENT")
        assert result_i.startswith("I-")

    def test_remap_all_dataset_labels(self, mapper):
        """Test remapping all dataset labels from config."""
        dataset_labels = mapper.remap.keys()

        for label in dataset_labels:
            b_label = f"B-{label}"
            i_label = f"I-{label}"

            # Should not raise exception
            b_result = mapper.remap_label(b_label)
            i_result = mapper.remap_label(i_label)

            # Should be valid HIPAA labels
            assert b_result in mapper.label_list
            assert i_result in mapper.label_list
            assert b_result.startswith("B-")
            assert i_result.startswith("I-")


class TestRemapLabelToId:
    """Test the remap_label_to_id method."""

    @pytest.fixture
    def mapper(self):
        """Create a LabelMapper instance for testing."""
        return LabelMapper()

    def test_remap_label_to_id_o(self, mapper):
        """Test remapping 'O' to ID."""
        assert mapper.remap_label_to_id("O") == 0

    def test_remap_label_to_id_patient(self, mapper):
        """Test remapping PATIENT to ID."""
        # B-PATIENT -> B-NAMES -> ID
        b_id = mapper.remap_label_to_id("B-PATIENT")
        assert b_id == mapper.label2id["B-NAMES"]

        # I-PATIENT -> I-NAMES -> ID
        i_id = mapper.remap_label_to_id("I-PATIENT")
        assert i_id == mapper.label2id["I-NAMES"]

    def test_remap_label_to_id_date(self, mapper):
        """Test remapping DATE to ID."""
        b_id = mapper.remap_label_to_id("B-DATE")
        assert b_id == mapper.label2id["B-DATES"]

    def test_remap_label_to_id_unknown(self, mapper):
        """Test remapping unknown label to ID."""
        unknown_id = mapper.remap_label_to_id("B-UNKNOWN")
        expected_id = mapper.label2id["B-ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"]
        assert unknown_id == expected_id

    def test_remap_label_to_id_returns_integer(self, mapper):
        """Test that remap_label_to_id returns integer."""
        result = mapper.remap_label_to_id("B-PATIENT")
        assert isinstance(result, int)


class TestGetCategoryInfo:
    """Test the get_category_info method."""

    @pytest.fixture
    def mapper(self):
        """Create a LabelMapper instance for testing."""
        return LabelMapper()

    def test_get_category_info_names(self, mapper):
        """Test getting info for NAMES category."""
        info = mapper.get_category_info("NAMES")

        assert info is not None
        assert info["name"] == "NAMES"
        assert "description" in info
        assert "bio_labels" in info
        assert info["bio_labels"] == ["B-NAMES", "I-NAMES"]
        assert info["prohibited"] is True

    def test_get_category_info_ssn(self, mapper):
        """Test getting info for SSN category."""
        info = mapper.get_category_info("SSN")

        assert info is not None
        assert info["name"] == "SSN"
        assert "Social Security" in info["description"]
        assert info["prohibited"] is True

    def test_get_category_info_nonexistent(self, mapper):
        """Test getting info for non-existent category."""
        info = mapper.get_category_info("NONEXISTENT")
        assert info is None

    def test_get_category_info_all_categories(self, mapper):
        """Test getting info for all categories."""
        for category in mapper.categories:
            info = mapper.get_category_info(category)
            assert info is not None
            assert "name" in info
            assert "description" in info
            assert "bio_labels" in info
            assert "prohibited" in info

    def test_get_category_info_structure(self, mapper):
        """Test structure of category info."""
        info = mapper.get_category_info("EMAIL_ADDRESSES")

        assert "id" in info
        assert "name" in info
        assert "description" in info
        assert "bio_labels" in info
        assert "examples" in info
        assert "prohibited" in info

        assert isinstance(info["bio_labels"], list)
        assert isinstance(info["examples"], list)
        assert isinstance(info["prohibited"], bool)


class TestIsProhibited:
    """Test the is_prohibited method."""

    @pytest.fixture
    def mapper(self):
        """Create a LabelMapper instance for testing."""
        return LabelMapper()

    def test_is_prohibited_o_label(self, mapper):
        """Test that 'O' is not prohibited."""
        assert not mapper.is_prohibited("O")

    def test_is_prohibited_b_names(self, mapper):
        """Test that B-NAMES is prohibited."""
        assert mapper.is_prohibited("B-NAMES")

    def test_is_prohibited_i_names(self, mapper):
        """Test that I-NAMES is prohibited."""
        assert mapper.is_prohibited("I-NAMES")

    def test_is_prohibited_b_ssn(self, mapper):
        """Test that B-SSN is prohibited."""
        assert mapper.is_prohibited("B-SSN")

    def test_is_prohibited_all_b_labels(self, mapper):
        """Test that all B- labels (except O) are prohibited."""
        for label in mapper.label_list:
            if label != "O" and label.startswith("B-"):
                assert mapper.is_prohibited(label), f"{label} should be prohibited"

    def test_is_prohibited_all_i_labels(self, mapper):
        """Test that all I- labels are prohibited."""
        for label in mapper.label_list:
            if label.startswith("I-"):
                assert mapper.is_prohibited(label), f"{label} should be prohibited"

    def test_is_prohibited_without_bio_prefix(self, mapper):
        """Test is_prohibited with category name (no BIO prefix)."""
        assert mapper.is_prohibited("NAMES")
        assert mapper.is_prohibited("SSN")
        assert mapper.is_prohibited("EMAIL_ADDRESSES")

    def test_is_prohibited_invalid_label(self, mapper):
        """Test is_prohibited with invalid label."""
        assert not mapper.is_prohibited("INVALID")
        assert not mapper.is_prohibited("X-NAMES")


class TestLabelMapperCustomConfig:
    """Test LabelMapper with custom config path."""

    def test_initialization_with_custom_path(self):
        """Test initialization with explicit config path."""
        config_path = Path(__file__).parent.parent / "configs" / "hipaa-v1.json"
        mapper = LabelMapper(config_path)

        assert mapper is not None
        assert mapper.num_labels == 37

    def test_invalid_config_path(self):
        """Test that invalid config path raises error."""
        with pytest.raises(FileNotFoundError):
            LabelMapper("/nonexistent/path/config.json")


class TestLabelMapperConfiguration:
    """Test configuration details."""

    @pytest.fixture
    def mapper(self):
        """Create a LabelMapper instance for testing."""
        return LabelMapper()

    def test_dataset_label_remap_completeness(self, mapper):
        """Test that dataset label remap is comprehensive."""
        remap = mapper.remap

        # Common dataset labels should be present
        common_labels = [
            "PATIENT", "DOCTOR", "USERNAME",
            "LOCATION", "HOSPITAL", "CITY", "STATE",
            "DATE", "AGE",
            "PHONE", "FAX", "EMAIL",
            "SSN", "MEDICALRECORD", "IDNUM"
        ]

        for label in common_labels:
            assert label in remap, f"Label {label} should be in remap"

    def test_all_remaps_to_valid_categories(self, mapper):
        """Test that all remaps point to valid HIPAA categories."""
        for dataset_label, hipaa_category in mapper.remap.items():
            assert hipaa_category in mapper.categories, \
                f"Remap target {hipaa_category} should be a valid category"

    def test_category_ids_are_sequential(self, mapper):
        """Test that category IDs are sequential."""
        categories = mapper.config["categories"]
        ids = [cat["id"] for cat in categories]

        assert ids == list(range(1, 19)), "Category IDs should be 1-18"

    def test_label_list_order_consistency(self, mapper):
        """Test that label list maintains consistent order."""
        # O should be first
        assert mapper.label_list[0] == "O"

        # Then pairs of B- and I- for each category
        for i in range(1, len(mapper.label_list), 2):
            if i + 1 < len(mapper.label_list):
                b_label = mapper.label_list[i]
                i_label = mapper.label_list[i + 1]

                assert b_label.startswith("B-"), f"{b_label} should start with B-"
                assert i_label.startswith("I-"), f"{i_label} should start with I-"

                # Should be same category
                b_category = b_label[2:]
                i_category = i_label[2:]
                assert b_category == i_category, \
                    f"B- and I- labels should be for same category: {b_label}, {i_label}"


class TestLabelMapperEdgeCases:
    """Test edge cases for LabelMapper."""

    @pytest.fixture
    def mapper(self):
        """Create a LabelMapper instance for testing."""
        return LabelMapper()

    def test_remap_with_extra_hyphens(self, mapper):
        """Test remapping label with extra hyphens."""
        # Should handle hyphenated category names
        result = mapper.remap_label("B-GEOGRAPHIC_SUBDIVISIONS")
        assert result == "B-GEOGRAPHIC_SUBDIVISIONS"

    def test_remap_empty_string(self, mapper):
        """Test remapping empty string."""
        # Should handle gracefully or return default
        result = mapper.remap_label("")
        # Either returns O or a default category
        assert result in mapper.label_list or result.startswith("B-")

    def test_get_category_info_case_sensitive(self, mapper):
        """Test that get_category_info is case-sensitive."""
        # Correct case
        assert mapper.get_category_info("NAMES") is not None

        # Wrong case
        assert mapper.get_category_info("names") is None
        assert mapper.get_category_info("Names") is None

    def test_is_prohibited_case_sensitive(self, mapper):
        """Test that is_prohibited is case-sensitive."""
        assert mapper.is_prohibited("NAMES")
        assert not mapper.is_prohibited("names")
        assert not mapper.is_prohibited("Names")
