# Quick Start Guide - Running Tests

Get started with the aare-edge test suite in under 5 minutes.

## Step 1: Install Dependencies

From the project root:

```bash
cd /Users/mkocher/dev-zone/aare-edge

# Install with dev dependencies
pip install -e ".[dev]"
```

Or install just pytest:

```bash
pip install pytest
```

## Step 2: Run Tests

### Run Everything (Recommended First Time)

```bash
pytest tests/ -v
```

Expected output:
```
tests/test_rules.py::TestPHIDetection::test_phi_detection_creation PASSED
tests/test_rules.py::TestPHIDetection::test_phi_detection_default_confidence PASSED
...
========================= X passed in X.XXs =========================
```

### Run Individual Test Files

```bash
# Test HIPAA rules
pytest tests/test_rules.py -v

# Test verifier
pytest tests/test_verifier.py -v

# Test extractors
pytest tests/test_extractor.py -v

# Test label mapper
pytest tests/test_label_mapper.py -v
```

## Step 3: Check Coverage

```bash
# Install coverage tool
pip install pytest-cov

# Run with coverage
pytest tests/ --cov=src --cov-report=term-missing

# Generate HTML coverage report
pytest tests/ --cov=src --cov-report=html
# Then open htmlcov/index.html in browser
```

## Common Commands

### Stop at First Failure
```bash
pytest tests/ -x
```

### Show Print Output
```bash
pytest tests/ -s
```

### Run Specific Test
```bash
# Run a specific test function
pytest tests/test_rules.py::TestPHIDetection::test_phi_detection_creation -v

# Run all tests matching a pattern
pytest tests/ -k "violation" -v
```

### Run with Detailed Output
```bash
pytest tests/ -vv --tb=long
```

## Expected Results

- **Total Tests**: ~164 tests
- **Expected Pass Rate**: 100%
- **Estimated Runtime**: < 5 seconds

## What Gets Tested

✓ **Rules Module** (test_rules.py)
- PHIDetection dataclass
- All 18 HIPAA Safe Harbor rules
- Z3 constraint generation
- Violation explanations

✓ **Verifier Module** (test_verifier.py)
- Verification engine
- Compliant/violation detection
- Proof generation
- JSON serialization

✓ **Extractor Module** (test_extractor.py)
- MockExtractor regex patterns
- SSN, phone, email, date, IP extraction
- PHIExtractor initialization

✓ **Label Mapper Module** (test_label_mapper.py)
- All 37 BIO labels
- Label remapping
- Category information

## Troubleshooting

### "ModuleNotFoundError: No module named 'src'"

Make sure you're running from project root:
```bash
cd /Users/mkocher/dev-zone/aare-edge
pytest tests/
```

### "FileNotFoundError: hipaa-v1.json"

Verify config file exists:
```bash
ls configs/hipaa-v1.json
```

### "ModuleNotFoundError: No module named 'z3'"

Install Z3:
```bash
pip install z3-solver
```

### "No module named pytest"

Install pytest:
```bash
pip install pytest
```

## Next Steps

1. ✓ Run all tests: `pytest tests/ -v`
2. ✓ Check coverage: `pytest tests/ --cov=src`
3. ✓ Read [README.md](README.md) for detailed documentation
4. ✓ Read [TEST_SUMMARY.md](TEST_SUMMARY.md) for test details

## Need Help?

- See [README.md](README.md) for full documentation
- See [TEST_SUMMARY.md](TEST_SUMMARY.md) for test statistics
- Check pytest docs: https://docs.pytest.org/

## Quick Verification

Run this to verify everything works:

```bash
cd /Users/mkocher/dev-zone/aare-edge && pytest tests/ -v --tb=short
```

If all tests pass ✓, you're good to go!
