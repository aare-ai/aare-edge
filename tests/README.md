# Aare Edge Test Suite

Comprehensive unit tests for the HIPAA verification system in the aare-edge project.

## Test Coverage

### 1. `test_rules.py` - HIPAA Rules Testing
Tests the core HIPAA compliance rules and Z3 constraint generation:

- **PHIDetection**: Dataclass creation, equality, default values
- **HIPAARules**: Initialization, config loading, all 18 HIPAA categories
- **Rule Operations**: get_rules(), get_rule_by_id(), get_rules_for_category()
- **Prohibition Checks**: get_prohibited_categories(), is_prohibited()
- **Z3 Constraints**: create_z3_constraints(), add_compliance_rule()
- **Violation Explanations**: create_violation_explanation()
- **Z3 Integration**: SAT/UNSAT verification, solver reusability

### 2. `test_verifier.py` - HIPAA Verifier Testing
Tests the verification engine and formal proof generation:

- **ComplianceStatus**: Enum values and membership
- **VerificationResult**: Creation, serialization (to_dict, to_json)
- **HIPAAVerifier**: Initialization, verify() for compliant/violation cases
- **Verification Scenarios**: Single PHI, multiple PHI, all 18 categories
- **Proof Content**: Verification that proofs contain expected information
- **Text Verification**: verify_text() with/without extractor
- **Batch Processing**: batch_verify() for multiple documents
- **JSON Support**: verify_from_json() with strings and dicts
- **Edge Cases**: Empty lists, overlapping detections, large datasets

### 3. `test_extractor.py` - PHI Extractor Testing
Tests entity extraction using regex patterns and model-based extraction:

- **ExtractionConfig**: Default and custom configurations
- **MockExtractor**: Regex pattern initialization and extraction
- **Pattern Matching**: SSN, phone numbers, emails, dates, IP addresses, MRNs
- **Format Variations**: Multiple formats for phones, emails, dates
- **Position Accuracy**: Verification of start/end positions
- **Multiple Entities**: Extracting multiple PHI types from one text
- **PHIExtractor**: Initialization, model loading error handling
- **JSON Conversion**: to_json() for entity serialization
- **Edge Cases**: Unicode, line breaks, tabs, very long text

### 4. `test_label_mapper.py` - Label Mapping Testing
Tests label conversion between dataset formats and HIPAA categories:

- **Config Loading**: load_hipaa_config() with default/explicit paths
- **LabelMapper**: Initialization, label2id, id2label mappings
- **All 37 Labels**: Verification that O + 18×2 (B-/I-) labels exist
- **Label Remapping**: remap_label() for all dataset label types
- **BIO Preservation**: Maintaining B- and I- prefixes
- **Category Info**: get_category_info() for all categories
- **Prohibition Checks**: is_prohibited() for all label types
- **Consistency**: label2id ↔ id2label inverse relationship
- **Dataset Labels**: PATIENT→NAMES, DOCTOR→NAMES, DATE→DATES, etc.

## Running Tests

### Install Dependencies

First, install the development dependencies:

```bash
pip install -e ".[dev]"
```

Or install pytest directly:

```bash
pip install pytest pytest-cov
```

### Run All Tests

```bash
# From project root
pytest tests/

# With verbose output
pytest tests/ -v

# With coverage report
pytest tests/ --cov=src --cov-report=term-missing

# With coverage HTML report
pytest tests/ --cov=src --cov-report=html
```

### Run Specific Test Files

```bash
# Test rules only
pytest tests/test_rules.py -v

# Test verifier only
pytest tests/test_verifier.py -v

# Test extractor only
pytest tests/test_extractor.py -v

# Test label mapper only
pytest tests/test_label_mapper.py -v
```

### Run Specific Test Classes or Functions

```bash
# Run a specific test class
pytest tests/test_rules.py::TestPHIDetection -v

# Run a specific test function
pytest tests/test_rules.py::TestPHIDetection::test_phi_detection_creation -v

# Run tests matching a pattern
pytest tests/ -k "test_violation" -v
```

### Run with Different Output Options

```bash
# Show print statements
pytest tests/ -v -s

# Stop at first failure
pytest tests/ -v -x

# Show local variables on failure
pytest tests/ -v -l

# Run in parallel (requires pytest-xdist)
pip install pytest-xdist
pytest tests/ -n auto
```

## Test Structure

```
tests/
├── __init__.py           # Package marker
├── conftest.py          # Shared fixtures and configuration
├── README.md            # This file
├── test_rules.py        # HIPAA rules tests (20+ test functions)
├── test_verifier.py     # Verifier tests (30+ test functions)
├── test_extractor.py    # Extractor tests (30+ test functions)
└── test_label_mapper.py # Label mapper tests (30+ test functions)
```

## Shared Fixtures (conftest.py)

The following fixtures are available in all test files:

- `project_root_path`: Path to project root
- `config_path`: Path to hipaa-v1.json config
- `sample_text_with_phi`: Text containing PHI for testing
- `sample_text_no_phi`: Clean text without PHI
- `sample_phi_detections`: List of sample PHIDetection objects

## Test Coverage Goals

- **Rules Module**: 100% coverage of rule definitions and constraint generation
- **Verifier Module**: 100% coverage of verification logic and proof generation
- **Extractor Module**: Pattern coverage (MockExtractor), initialization logic (PHIExtractor)
- **Label Mapper Module**: 100% coverage of label mapping and conversions

## Notes

- Tests do NOT require a trained model (uses MockExtractor for extraction tests)
- Tests use the actual hipaa-v1.json config file from the configs/ directory
- Z3 solver is used in actual verification (not mocked)
- All 18 HIPAA Safe Harbor categories are tested
- Tests include edge cases, error conditions, and integration scenarios

## CI/CD Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
- name: Run tests
  run: |
    pip install -e ".[dev]"
    pytest tests/ -v --cov=src --cov-report=xml

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    file: ./coverage.xml
```

## Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Ensure all tests pass: `pytest tests/ -v`
3. Check coverage: `pytest tests/ --cov=src --cov-report=term-missing`
4. Aim for 90%+ coverage on new code
5. Add docstrings to test functions explaining what they test

## Troubleshooting

### Import Errors

If you get import errors, ensure you're running from the project root:

```bash
cd /path/to/aare-edge
pytest tests/
```

Or set PYTHONPATH:

```bash
export PYTHONPATH=/path/to/aare-edge:$PYTHONPATH
pytest tests/
```

### Config Not Found

Tests expect the hipaa-v1.json config at `configs/hipaa-v1.json`. Verify:

```bash
ls configs/hipaa-v1.json
```

### Z3 Import Errors

If Z3 is not installed:

```bash
pip install z3-solver
```

## Test Statistics

- **Total Test Files**: 4
- **Total Test Functions**: ~110+
- **Total Test Classes**: ~30+
- **Estimated Runtime**: < 5 seconds (without model loading)
