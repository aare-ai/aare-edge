#!/usr/bin/env python3
"""
Generate augmented training data for HIPAA PHI NER.

This script creates synthetic examples with diverse format variations
for structured PHI types that are poorly represented in the i2b2 dataset.
"""

import json
import random
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)

# Templates for generating contextual sentences
TEMPLATES = {
    "SSN": [
        "Patient SSN: {value}",
        "SSN {value}",
        "Social Security Number: {value}",
        "social security number {value}",
        "SSN: {value} on file",
        "The patient's SSN is {value}",
        "Verified SSN {value}",
        "SS# {value}",
        "Social: {value}",
    ],
    "PHONE": [
        "Phone: {value}",
        "Tel: {value}",
        "Telephone: {value}",
        "Contact number: {value}",
        "Call {value}",
        "Reach patient at {value}",
        "Phone number {value}",
        "Mobile: {value}",
        "Cell: {value}",
        "Home phone: {value}",
        "Work: {value}",
        "Emergency contact: {value}",
    ],
    "FAX": [
        "Fax: {value}",
        "Fax number: {value}",
        "Send fax to {value}",
        "Fax results to {value}",
        "F: {value}",
    ],
    "EMAIL": [
        "Email: {value}",
        "E-mail: {value}",
        "Contact at {value}",
        "Send to {value}",
        "Patient email: {value}",
        "Reach via {value}",
    ],
    "DATE": [
        "DOB: {value}",
        "Date of Birth: {value}",
        "Born {value}",
        "Birthday: {value}",
        "Admission date: {value}",
        "Admitted {value}",
        "Discharge date: {value}",
        "Discharged {value}",
        "Visit date: {value}",
        "Appointment: {value}",
        "Scheduled for {value}",
        "Last seen {value}",
        "Follow-up: {value}",
    ],
    "MRN": [
        "MRN: {value}",
        "MRN {value}",
        "Medical Record Number: {value}",
        "Medical Record #: {value}",
        "Record #: {value}",
        "Chart #: {value}",
        "Patient ID: {value}",
        "ID: {value}",
    ],
    "ACCOUNT": [
        "Account: {value}",
        "Account #: {value}",
        "Account Number: {value}",
        "Acct: {value}",
        "Billing account: {value}",
    ],
    "HEALTH_PLAN": [
        "Insurance ID: {value}",
        "Member ID: {value}",
        "Policy #: {value}",
        "Policy Number: {value}",
        "Health Plan ID: {value}",
        "Subscriber ID: {value}",
        "Group #: {value}",
    ],
    "LICENSE": [
        "License #: {value}",
        "License: {value}",
        "DL: {value}",
        "Driver's License: {value}",
        "Certificate #: {value}",
    ],
    "IP": [
        "IP: {value}",
        "IP Address: {value}",
        "From IP {value}",
        "Connected from {value}",
        "Client IP: {value}",
    ],
    "URL": [
        "URL: {value}",
        "Website: {value}",
        "Portal: {value}",
        "Link: {value}",
        "Visit {value}",
    ],
}


def generate_ssn_formats() -> List[str]:
    """Generate SSN in various formats."""
    formats = []
    for _ in range(100):
        area = random.randint(100, 999)
        group = random.randint(10, 99)
        serial = random.randint(1000, 9999)

        formats.append(f"{area}-{group}-{serial}")      # 123-45-6789
        formats.append(f"{area}{group}{serial}")        # 123456789
        formats.append(f"{area} {group} {serial}")      # 123 45 6789
        formats.append(f"{area}.{group}.{serial}")      # 123.45.6789
    return formats


def generate_phone_formats() -> List[str]:
    """Generate phone numbers in various formats."""
    formats = []
    for _ in range(100):
        area = random.randint(200, 999)
        exchange = random.randint(200, 999)
        subscriber = random.randint(1000, 9999)

        formats.append(f"({area}) {exchange}-{subscriber}")   # (555) 123-4567
        formats.append(f"{area}-{exchange}-{subscriber}")     # 555-123-4567
        formats.append(f"{area}.{exchange}.{subscriber}")     # 555.123.4567
        formats.append(f"{area} {exchange} {subscriber}")     # 555 123 4567
        formats.append(f"{area}{exchange}{subscriber}")       # 5551234567
        formats.append(f"1-{area}-{exchange}-{subscriber}")   # 1-555-123-4567
        formats.append(f"+1 {area} {exchange} {subscriber}")  # +1 555 123 4567
        formats.append(f"+1-{area}-{exchange}-{subscriber}")  # +1-555-123-4567
    return formats


def generate_date_formats() -> List[str]:
    """Generate dates in various formats."""
    formats = []
    start_date = datetime(1940, 1, 1)
    end_date = datetime(2024, 12, 31)

    for _ in range(100):
        days = random.randint(0, (end_date - start_date).days)
        date = start_date + timedelta(days=days)

        formats.append(date.strftime("%m/%d/%Y"))      # 01/15/1985
        formats.append(date.strftime("%m-%d-%Y"))      # 01-15-1985
        formats.append(date.strftime("%Y-%m-%d"))      # 1985-01-15
        formats.append(date.strftime("%d/%m/%Y"))      # 15/01/1985
        formats.append(date.strftime("%B %d, %Y"))     # January 15, 1985
        formats.append(date.strftime("%b %d, %Y"))     # Jan 15, 1985
        formats.append(date.strftime("%m/%d/%y"))      # 01/15/85
        formats.append(date.strftime("%d %B %Y"))      # 15 January 1985
        formats.append(date.strftime("%m.%d.%Y"))      # 01.15.1985
    return formats


def generate_mrn_formats() -> List[str]:
    """Generate MRN in various formats."""
    formats = []
    for _ in range(100):
        num = random.randint(100000, 99999999)
        prefix = random.choice(["", "A-", "MR", "P", "PT-", ""])

        formats.append(f"{prefix}{num}")
        formats.append(f"{prefix}{num:08d}")
        formats.append(f"{random.choice(['A', 'B', 'M', 'P'])}{num}")
    return formats


def generate_email_formats() -> List[str]:
    """Generate email addresses."""
    formats = []
    domains = ["gmail.com", "yahoo.com", "outlook.com", "hospital.org",
               "clinic.com", "healthcare.net", "medical.org", "health.com"]

    for _ in range(100):
        first = fake.first_name().lower()
        last = fake.last_name().lower()
        domain = random.choice(domains)

        formats.append(f"{first}.{last}@{domain}")
        formats.append(f"{first}{last}@{domain}")
        formats.append(f"{first}_{last}@{domain}")
        formats.append(f"{first[0]}{last}@{domain}")
        formats.append(f"{first}{last[0]}@{domain}")
        formats.append(f"{first}.{last}{random.randint(1, 99)}@{domain}")
    return formats


def generate_ip_formats() -> List[str]:
    """Generate IP addresses."""
    formats = []
    for _ in range(100):
        # IPv4
        ip = f"{random.randint(1, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 255)}"
        formats.append(ip)

        # Some common private ranges
        formats.append(f"192.168.{random.randint(0, 255)}.{random.randint(1, 255)}")
        formats.append(f"10.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 255)}")
    return formats


def generate_url_formats() -> List[str]:
    """Generate URLs."""
    formats = []
    domains = ["patient-portal", "myhealth", "healthrecords", "medicalchart"]
    tlds = [".com", ".org", ".net", ".health"]

    for _ in range(50):
        domain = random.choice(domains)
        tld = random.choice(tlds)
        path = random.choice(["", "/login", "/records", f"/patient/{random.randint(1000, 9999)}"])

        formats.append(f"https://{domain}{tld}{path}")
        formats.append(f"http://{domain}{tld}{path}")
        formats.append(f"www.{domain}{tld}{path}")
    return formats


def generate_account_formats() -> List[str]:
    """Generate account numbers."""
    formats = []
    for _ in range(100):
        num = random.randint(10000, 9999999999)
        formats.append(str(num))
        formats.append(f"A{num}")
        formats.append(f"{num:010d}")
    return formats


def generate_health_plan_formats() -> List[str]:
    """Generate health plan IDs."""
    formats = []
    prefixes = ["XYZ", "ABC", "MED", "HLT", "INS", "POL", "GRP", ""]

    for _ in range(100):
        prefix = random.choice(prefixes)
        num = random.randint(100000, 999999999)

        formats.append(f"{prefix}{num}")
        formats.append(f"{prefix}-{num}")
        formats.append(f"{prefix}{num:09d}")
    return formats


def generate_license_formats() -> List[str]:
    """Generate license/certificate numbers."""
    formats = []
    states = ["CA", "NY", "TX", "FL", "IL", "PA", "OH", "GA", "NC", "MI"]

    for _ in range(100):
        state = random.choice(states)
        num = random.randint(1000000, 99999999)
        letter = random.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

        formats.append(f"{state}{num}")
        formats.append(f"{letter}{num}")
        formats.append(f"{state}-{num}")
        formats.append(f"DL-{num}")
    return formats


def create_bio_labels(text: str, entity_start: int, entity_end: int, entity_type: str) -> List[Tuple[str, str]]:
    """Create BIO labels for a text with one entity."""
    tokens = []
    labels = []

    # Simple whitespace tokenization for label generation
    current_pos = 0
    for word in text.split():
        word_start = text.find(word, current_pos)
        word_end = word_start + len(word)

        # Check if this word overlaps with the entity
        if word_start >= entity_start and word_end <= entity_end:
            # This word is part of the entity
            if word_start == entity_start:
                labels.append(f"B-{entity_type}")
            else:
                labels.append(f"I-{entity_type}")
        else:
            labels.append("O")

        tokens.append(word)
        current_pos = word_end

    return list(zip(tokens, labels))


def generate_examples(entity_type: str, values: List[str], templates: List[str], count: int = 500) -> List[Dict]:
    """Generate training examples for an entity type."""
    examples = []

    for _ in range(count):
        value = random.choice(values)
        template = random.choice(templates)
        text = template.format(value=value)

        # Find entity position
        entity_start = text.find(value)
        entity_end = entity_start + len(value)

        # Create token/label pairs
        token_labels = create_bio_labels(text, entity_start, entity_end, entity_type)

        examples.append({
            "text": text,
            "tokens": [t[0] for t in token_labels],
            "labels": [t[1] for t in token_labels],
            "entities": [{
                "type": entity_type,
                "text": value,
                "start": entity_start,
                "end": entity_end
            }]
        })

    return examples


def generate_compound_examples(count: int = 1000) -> List[Dict]:
    """Generate examples with multiple PHI types in one sentence."""
    examples = []

    compound_templates = [
        "Patient {name}, DOB: {date}, SSN: {ssn}, Phone: {phone}",
        "{name} (DOB {date}) - Contact: {phone}, Email: {email}",
        "Name: {name}, MRN: {mrn}, SSN: {ssn}",
        "Pt {name}, {date}, reached at {phone}",
        "{name}, born {date}, SSN {ssn}, lives at {location}",
        "Contact {name} at {phone} or {email}",
        "Patient {name} (MRN: {mrn}) admitted {date}",
        "{name}, DOB: {date}, Phone: {phone}, Fax: {fax}",
    ]

    for _ in range(count):
        template = random.choice(compound_templates)

        # Generate values
        name = fake.name()
        date = random.choice(generate_date_formats()[:20])
        ssn = random.choice(generate_ssn_formats()[:20])
        phone = random.choice(generate_phone_formats()[:20])
        email = random.choice(generate_email_formats()[:20])
        mrn = random.choice(generate_mrn_formats()[:20])
        fax = random.choice(generate_phone_formats()[:20])
        location = f"{fake.street_address()}, {fake.city()}"

        # Format text
        try:
            text = template.format(
                name=name, date=date, ssn=ssn, phone=phone,
                email=email, mrn=mrn, fax=fax, location=location
            )
        except KeyError:
            continue

        # Simple tokenization
        tokens = text.split()
        labels = ["O"] * len(tokens)
        entities = []

        # Find and label each entity
        entity_map = {
            "NAME": name,
            "DATE": date,
            "SSN": ssn,
            "PHONE": phone,
            "EMAIL": email,
            "MRN": mrn,
            "LOCATION": location,
        }

        for etype, value in entity_map.items():
            if value in text:
                start = text.find(value)
                end = start + len(value)
                entities.append({
                    "type": etype,
                    "text": value,
                    "start": start,
                    "end": end
                })

                # Update labels
                current_pos = 0
                for i, token in enumerate(tokens):
                    token_start = text.find(token, current_pos)
                    token_end = token_start + len(token)

                    if token_start >= start and token_end <= end:
                        if labels[i] == "O":  # Don't overwrite
                            if token_start == start:
                                labels[i] = f"B-{etype}"
                            else:
                                labels[i] = f"I-{etype}"

                    current_pos = token_end

        examples.append({
            "text": text,
            "tokens": tokens,
            "labels": labels,
            "entities": entities
        })

    return examples


def main():
    print("Generating augmented HIPAA PHI training data...")

    all_examples = []

    # Generate single-entity examples
    print("Generating SSN examples...")
    all_examples.extend(generate_examples("SSN", generate_ssn_formats(), TEMPLATES["SSN"], 500))

    print("Generating PHONE examples...")
    all_examples.extend(generate_examples("PHONE", generate_phone_formats(), TEMPLATES["PHONE"], 500))

    print("Generating DATE examples...")
    all_examples.extend(generate_examples("DATE", generate_date_formats(), TEMPLATES["DATE"], 500))

    print("Generating EMAIL examples...")
    all_examples.extend(generate_examples("EMAIL", generate_email_formats(), TEMPLATES["EMAIL"], 300))

    print("Generating MRN examples...")
    all_examples.extend(generate_examples("MRN", generate_mrn_formats(), TEMPLATES["MRN"], 300))

    print("Generating ACCOUNT examples...")
    all_examples.extend(generate_examples("ACCOUNT", generate_account_formats(), TEMPLATES["ACCOUNT"], 200))

    print("Generating HEALTH_PLAN examples...")
    all_examples.extend(generate_examples("HEALTH_PLAN", generate_health_plan_formats(), TEMPLATES["HEALTH_PLAN"], 200))

    print("Generating LICENSE examples...")
    all_examples.extend(generate_examples("LICENSE", generate_license_formats(), TEMPLATES["LICENSE"], 200))

    print("Generating IP examples...")
    all_examples.extend(generate_examples("IP", generate_ip_formats(), TEMPLATES["IP"], 200))

    print("Generating URL examples...")
    all_examples.extend(generate_examples("URL", generate_url_formats(), TEMPLATES["URL"], 100))

    print("Generating FAX examples...")
    all_examples.extend(generate_examples("FAX", generate_phone_formats(), TEMPLATES["FAX"], 200))

    # Generate compound examples
    print("Generating compound examples...")
    all_examples.extend(generate_compound_examples(1500))

    # Shuffle
    random.shuffle(all_examples)

    # Split into train/val/test
    n = len(all_examples)
    train_end = int(n * 0.8)
    val_end = int(n * 0.9)

    train_data = all_examples[:train_end]
    val_data = all_examples[train_end:val_end]
    test_data = all_examples[val_end:]

    # Save
    output_dir = "/Users/mkocher/dev-zone/aare-edge/data/augmented"
    import os
    os.makedirs(output_dir, exist_ok=True)

    with open(f"{output_dir}/train.json", "w") as f:
        json.dump(train_data, f, indent=2)

    with open(f"{output_dir}/val.json", "w") as f:
        json.dump(val_data, f, indent=2)

    with open(f"{output_dir}/test.json", "w") as f:
        json.dump(test_data, f, indent=2)

    print(f"\nGenerated {len(all_examples)} total examples:")
    print(f"  Train: {len(train_data)}")
    print(f"  Val:   {len(val_data)}")
    print(f"  Test:  {len(test_data)}")
    print(f"\nSaved to {output_dir}/")

    # Print sample
    print("\nSample examples:")
    for ex in random.sample(all_examples, 5):
        print(f"  Text: {ex['text']}")
        print(f"  Labels: {list(zip(ex['tokens'], ex['labels']))}")
        print()


if __name__ == "__main__":
    main()
