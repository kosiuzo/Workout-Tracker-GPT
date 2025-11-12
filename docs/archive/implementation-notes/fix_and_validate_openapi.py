#!/usr/bin/env python3
"""
OpenAPI Spec Fixer and Validator
Fixes Swagger 2.0 issues and validates OpenAPI specs
"""

import json
import sys
from pathlib import Path
from typing import Dict, Tuple, List

def fix_swagger_2_0(spec_dict: Dict) -> List[str]:
    """Fix common Swagger 2.0 issues"""
    fixes_applied = []

    # Fix 1: Remove empty enums from parameters
    if 'parameters' in spec_dict:
        for param_key, param in spec_dict['parameters'].items():
            if isinstance(param, dict):
                if 'enum' in param and param['enum'] == []:
                    del param['enum']
                    fixes_applied.append(f"Removed empty enum from parameter '{param_key}'")

    # Fix 2: Clean trailing whitespace/garbage
    # (This would be handled during JSON parsing)

    return fixes_applied

def load_spec(filepath: str) -> Dict:
    """Load JSON/YAML spec file"""
    filepath = Path(filepath)

    if not filepath.exists():
        raise FileNotFoundError(f"File not found: {filepath}")

    with open(filepath, 'r') as f:
        content = f.read()

        # Handle files with trailing garbage
        if filepath.suffix in ['.json', '.yml', '.yaml']:
            try:
                # Try to find the last complete JSON object
                last_brace = content.rfind('}')
                if last_brace != -1:
                    content = content[:last_brace + 1]
                return json.loads(content)
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON in {filepath}: {e}")

    raise ValueError(f"Unsupported file format: {filepath}")

def save_spec(spec_dict: Dict, filepath: str, pretty: bool = True) -> None:
    """Save spec to file"""
    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)

    with open(filepath, 'w') as f:
        if pretty:
            json.dump(spec_dict, f, indent=2)
        else:
            json.dump(spec_dict, f)

def validate_spec(spec_dict: Dict) -> Tuple[bool, str]:
    """Validate spec using openapi-spec-validator"""
    try:
        from openapi_spec_validator import validate_spec as validate
        from openapi_spec_validator.validation.exceptions import OpenAPIValidationError

        validate(spec_dict)
        return True, "✅ Spec is valid!"

    except ImportError:
        return None, "⚠️  openapi-spec-validator not installed. Install with: pip install openapi-spec-validator"

    except Exception as e:
        error_msg = str(e)
        # Truncate long error messages
        if len(error_msg) > 300:
            error_msg = error_msg[:300] + "..."
        return False, f"❌ Validation error: {error_msg}"

def print_section(title: str) -> None:
    """Print a formatted section header"""
    print(f"\n{'=' * 70}")
    print(f"  {title}")
    print(f"{'=' * 70}")

def main():
    # Define paths
    swagger_file = "swagger_2.0.yml"
    fixed_file = "swagger_2.0_fixed.json"

    print_section("OpenAPI Spec Fixer & Validator")
    print(f"Swagger 2.0 file: {swagger_file}")
    print(f"Output file: {fixed_file}")

    # Step 1: Load spec
    print(f"\n1️⃣  Loading spec from '{swagger_file}'...")
    try:
        spec = load_spec(swagger_file)
        file_size = Path(swagger_file).stat().st_size
        print(f"   ✅ Loaded successfully ({file_size:,} bytes)")
        print(f"   📊 API Title: {spec.get('info', {}).get('title', 'N/A')}")
        print(f"   📊 Version: {spec.get('info', {}).get('version', 'N/A')}")
        print(f"   📊 Paths: {len(spec.get('paths', {}))}")
        print(f"   📊 Definitions: {len(spec.get('definitions', {}))}")
    except FileNotFoundError as e:
        print(f"   ❌ {e}")
        sys.exit(1)
    except Exception as e:
        print(f"   ❌ Error loading spec: {e}")
        sys.exit(1)

    # Step 2: Fix issues
    print(f"\n2️⃣  Applying fixes...")
    fixes = fix_swagger_2_0(spec)
    if fixes:
        for fix in fixes:
            print(f"   ✅ {fix}")
        print(f"   📌 Total fixes applied: {len(fixes)}")
    else:
        print(f"   ℹ️  No fixes needed")

    # Step 3: Save fixed spec
    print(f"\n3️⃣  Saving fixed spec to '{fixed_file}'...")
    try:
        save_spec(spec, fixed_file, pretty=True)
        file_size = Path(fixed_file).stat().st_size
        print(f"   ✅ Saved successfully ({file_size:,} bytes)")
    except Exception as e:
        print(f"   ❌ Error saving spec: {e}")
        sys.exit(1)

    # Step 4: Validate fixed spec
    print(f"\n4️⃣  Validating fixed spec...")
    is_valid, message = validate_spec(spec)

    if is_valid is None:
        print(f"   {message}")
        print(f"   Install with: pip install openapi-spec-validator")
    elif is_valid:
        print(f"   {message}")
        print(f"   ✨ All validation errors have been fixed!")
    else:
        print(f"   {message}")
        sys.exit(1)

    # Summary
    print_section("Summary")
    print(f"✅ Fixed swagger file saved to: {fixed_file}")
    print(f"\n📋 What was fixed:")
    if fixes:
        for i, fix in enumerate(fixes, 1):
            print(f"   {i}. {fix}")
    else:
        print(f"   No issues found")

    print(f"\n🚀 Next steps:")
    print(f"   1. Convert to OpenAPI 3.0 using swagger2openapi:")
    print(f"      swagger2openapi {fixed_file} -o openapi_3.0.json")
    print(f"\n   2. (Optional) Convert to OpenAPI 3.1 by updating the version in the JSON")
    print(f"\n   3. Validate the OpenAPI spec:")
    print(f"      python fix_and_validate_openapi.py openapi_3.0.json")

    print_section("Done")

if __name__ == "__main__":
    main()
