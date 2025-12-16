"""Pytest configuration and shared fixtures for aare-edge tests."""

import sys
from pathlib import Path

import pytest

# Add project root to path for all tests
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


@pytest.fixture
def project_root_path():
    """Return the project root path."""
    return Path(__file__).parent.parent


@pytest.fixture
def config_path():
    """Return the path to hipaa-v1.json config file."""
    return Path(__file__).parent.parent / "configs" / "hipaa-v1.json"


@pytest.fixture
def sample_text_with_phi():
    """Return sample text containing various PHI elements."""
    return """
    PATIENT INFORMATION
    Name: John Smith
    MRN: 123456
    DOB: 01/15/1980
    Phone: (555) 123-4567
    Email: john.smith@email.com
    SSN: 123-45-6789

    CLINICAL NOTES
    Patient was admitted on 03/20/2024.
    Address: 123 Main Street, Boston, MA 02115
    IP Address: 192.168.1.100
    """


@pytest.fixture
def sample_text_no_phi():
    """Return sample text without PHI."""
    return """
    The patient was diagnosed with type 2 diabetes mellitus.
    Treatment plan includes lifestyle modifications and medication.
    Follow-up appointment scheduled for next month.
    """


@pytest.fixture
def sample_phi_detections():
    """Return sample PHI detections for testing."""
    from src.verification.rules import PHIDetection

    return [
        PHIDetection("NAMES", "John Smith", 0, 10, 0.95),
        PHIDetection("SSN", "123-45-6789", 20, 31, 0.99),
        PHIDetection("EMAIL_ADDRESSES", "john@example.com", 40, 56, 0.88),
        PHIDetection("DATES", "01/15/2024", 70, 80, 0.92),
    ]
