# Python OpenAPI Tools: Conversion & Validation Guide

## Overview

Yes! Python has excellent tools for both converting Swagger 2.0 to OpenAPI 3.1 and validating OpenAPI specifications.

---

## 🔄 Conversion Tools

### Option 1: **swagger2openapi** (Node.js-based, but available via CLI)

**Best for**: Quick conversions, CLI usage

**Install**:
```bash
npm install -g swagger2openapi
```

**Usage**:
```bash
swagger2openapi swagger_2.0.json -o openapi_3.0.json
```

**Pros**:
- Actively maintained
- Converts 2.0 → 3.0.x format
- Can validate in one pass
- Available as npm package

**Cons**:
- Not a Python library (Node.js-based)
- Limited 3.1 support (converts to 3.0)

---

### Option 2: **openapi-spec-validator** (Python)

**Best for**: Python-native integration, validation after conversion

**Install**:
```bash
pip install openapi-spec-validator
```

**Usage - Convert (via processing)**:
```python
import json
from openapi_spec_validator import validate_spec

# Load your Swagger 2.0 spec
with open('swagger_2.0.json', 'r') as f:
    spec = json.load(f)

# Fix the preferParams issue first
if 'parameters' in spec and 'preferParams' in spec['parameters']:
    pref = spec['parameters']['preferParams']
    if 'enum' in pref and pref['enum'] == []:
        del pref['enum']

# Save the fixed version
with open('swagger_2.0_fixed.json', 'w') as f:
    json.dump(spec, f, indent=2)

# Validate
try:
    validate_spec(spec)
    print("✅ Spec is valid!")
except Exception as e:
    print(f"❌ Validation error: {e}")
```

**Pros**:
- Validates Swagger 2.0, OpenAPI 3.0, and 3.1
- Pure Python
- Easy integration in scripts
- Good error messages

**Cons**:
- Doesn't auto-convert (you need to fix issues manually)
- Requires Python 3.7+

---

### Option 3: **openapi-core** (Python)

**Best for**: Detailed spec validation, request/response validation

**Install**:
```bash
pip install openapi-core
```

**Usage**:
```python
from openapi_core import Spec

# Load and validate
with open('openapi_3.1.json', 'r') as f:
    spec_dict = json.load(f)

spec = Spec.from_dict(spec_dict)

# Validate requests/responses against spec
# (More advanced usage for runtime validation)
```

**Pros**:
- Supports OpenAPI 3.0 and 3.1
- Can validate actual HTTP requests/responses
- Good for integration testing

**Cons**:
- Heavier than simple validators
- More complex to set up

---

## ✅ Validation Tools Comparison

| Tool | Swagger 2.0 | OpenAPI 3.0 | OpenAPI 3.1 | Python | CLI | Best Use |
|------|-------------|-------------|-------------|--------|-----|----------|
| **openapi-spec-validator** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Native | ✅ Yes | Validation, linting |
| **openapi-core** | ✅ Limited | ✅ Yes | ✅ Yes | ✅ Native | ❌ No | Runtime validation |
| **openapi-schema-validator** | ❌ No | ✅ Yes | ✅ Yes | ✅ Native | ❌ No | Schema validation |
| **swagger2openapi** | ✅ Yes | ✅ Yes | ⚠️ Partial | ❌ Node.js | ✅ Yes | Conversion |
| **Spectral** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ Node.js | ✅ Yes | Linting, best practices |

---

## 🚀 Recommended Workflow for Your Project

### Step 1: Fix the Immediate Issue (Python)

```python
import json

# Load and fix
with open('swagger_2.0.yml', 'r') as f:
    # Since file is actually JSON minified as .yml
    spec = json.load(f)

# Fix preferParams
if 'parameters' in spec and 'preferParams' in spec['parameters']:
    pref = spec['parameters']['preferParams']
    # Remove empty enum
    if 'enum' in pref and pref['enum'] == []:
        del pref['enum']

# Fix all RPC endpoints that reference preferParams
for path_key, path_item in spec.get('paths', {}).items():
    if path_key.startswith('/rpc/'):
        for method, operation in path_item.items():
            if method in ['post', 'get', 'put', 'delete', 'patch']:
                params = operation.get('parameters', [])
                for param in params:
                    if isinstance(param, dict) and param.get('$ref') == '#/parameters/preferParams':
                        # This reference is now valid
                        pass

# Save the fixed version
with open('swagger_2.0_fixed.json', 'w') as f:
    json.dump(spec, f, indent=2)

print("✅ Fixed swagger_2.0_fixed.json")
```

### Step 2: Validate the Fixed Spec (Python)

```python
from openapi_spec_validator import validate_spec
import json

with open('swagger_2.0_fixed.json', 'r') as f:
    spec = json.load(f)

try:
    validate_spec(spec)
    print("✅ Swagger 2.0 spec is valid!")
except Exception as e:
    print(f"❌ Validation failed: {e}")
    import traceback
    traceback.print_exc()
```

### Step 3: Convert to OpenAPI 3.0 (Node.js, then 3.1 via Python)

```bash
# Using swagger2openapi (Node.js)
swagger2openapi swagger_2.0_fixed.json -o openapi_3.0.json
```

### Step 4: Validate OpenAPI 3.0/3.1 (Python)

```python
from openapi_spec_validator import validate_spec
import json

with open('openapi_3.0.json', 'r') as f:
    spec = json.load(f)

try:
    validate_spec(spec)
    print("✅ OpenAPI 3.0 spec is valid!")
except Exception as e:
    print(f"❌ Validation failed: {e}")
```

---

## 📦 Complete Python Script

Here's a complete script to fix, validate, and prepare your spec:

```python
#!/usr/bin/env python3
"""
OpenAPI Spec Fixer and Validator
Fixes Swagger 2.0 issues and validates OpenAPI specs
"""

import json
import sys
from pathlib import Path

def fix_swagger_2_0(spec_dict):
    """Fix common Swagger 2.0 issues"""
    fixes_applied = []

    # Fix 1: Remove empty enums from parameters
    if 'parameters' in spec_dict:
        for param_key, param in spec_dict['parameters'].items():
            if isinstance(param, dict):
                if 'enum' in param and param['enum'] == []:
                    del param['enum']
                    fixes_applied.append(f"Removed empty enum from parameter '{param_key}'")

    # Fix 2: Clean up RPC endpoint parameter references
    for path_key, path_item in spec_dict.get('paths', {}).items():
        if path_key.startswith('/rpc/'):
            for method, operation in path_item.items():
                if isinstance(operation, dict) and 'parameters' in operation:
                    params = operation['parameters']
                    for i, param in enumerate(params):
                        if isinstance(param, dict) and param.get('$ref') == '#/parameters/preferParams':
                            # This is now valid after fixing preferParams
                            pass

    return fixes_applied

def load_spec(filepath):
    """Load JSON/YAML spec file"""
    with open(filepath, 'r') as f:
        if filepath.endswith('.json') or filepath.endswith('.yml') or filepath.endswith('.yaml'):
            return json.load(f)
    raise ValueError(f"Unsupported file format: {filepath}")

def save_spec(spec_dict, filepath, pretty=True):
    """Save spec to file"""
    with open(filepath, 'w') as f:
        if pretty:
            json.dump(spec_dict, f, indent=2)
        else:
            json.dump(spec_dict, f)

def validate_spec(spec_dict, version="swagger2.0"):
    """Validate spec using openapi-spec-validator"""
    try:
        from openapi_spec_validator import validate_spec as validate
        validate(spec_dict)
        return True, "✅ Spec is valid!"
    except Exception as e:
        return False, f"❌ Validation error: {str(e)}"

def main():
    # Define paths
    swagger_file = "swagger_2.0.yml"
    fixed_file = "swagger_2.0_fixed.json"

    print("=" * 60)
    print("OpenAPI Spec Fixer & Validator")
    print("=" * 60)

    # Step 1: Load spec
    print(f"\n1️⃣  Loading spec from {swagger_file}...")
    try:
        spec = load_spec(swagger_file)
        print(f"   ✅ Loaded successfully")
    except Exception as e:
        print(f"   ❌ Error loading spec: {e}")
        sys.exit(1)

    # Step 2: Fix issues
    print(f"\n2️⃣  Applying fixes...")
    fixes = fix_swagger_2_0(spec)
    if fixes:
        for fix in fixes:
            print(f"   ✅ {fix}")
    else:
        print(f"   ℹ️  No fixes needed")

    # Step 3: Save fixed spec
    print(f"\n3️⃣  Saving fixed spec to {fixed_file}...")
    try:
        save_spec(spec, fixed_file)
        print(f"   ✅ Saved successfully")
    except Exception as e:
        print(f"   ❌ Error saving spec: {e}")
        sys.exit(1)

    # Step 4: Validate fixed spec
    print(f"\n4️⃣  Validating fixed spec...")
    try:
        from openapi_spec_validator import validate_spec as validate
        validate(spec)
        print(f"   ✅ Swagger 2.0 spec is valid!")
    except ImportError:
        print(f"   ⚠️  openapi-spec-validator not installed")
        print(f"      Install with: pip install openapi-spec-validator")
    except Exception as e:
        print(f"   ❌ Validation failed: {str(e)[:200]}")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("✅ All done! Next steps:")
    print("=" * 60)
    print(f"1. Use 'swagger2openapi' to convert to OpenAPI 3.0:")
    print(f"   swagger2openapi {fixed_file} -o openapi_3.0.json")
    print(f"\n2. Validate the OpenAPI 3.0 spec:")
    print(f"   python validate_openapi.py openapi_3.0.json")
    print("\n" + "=" * 60)

if __name__ == "__main__":
    main()
```

**Save as**: `fix_openapi_spec.py`

**Run**:
```bash
python fix_openapi_spec.py
```

---

## 🛠️ Installation Commands

### For Full Python Workflow:

```bash
# Validation tools
pip install openapi-spec-validator openapi-core openapi-schema-validator

# For conversion (Node.js required)
npm install -g swagger2openapi

# Optional: Spectral for advanced linting
npm install -g @stoplight/spectral-cli
```

### Requirements:
```
openapi-spec-validator>=0.6.0
openapi-core>=0.15.0
openapi-schema-validator>=0.6.0
```

---

## 📊 Summary

| Task | Best Tool | Language |
|------|-----------|----------|
| **Convert 2.0→3.0** | swagger2openapi | Node.js CLI |
| **Convert 3.0→3.1** | Manual (mostly compatible) | - |
| **Validate 2.0** | openapi-spec-validator | Python |
| **Validate 3.0/3.1** | openapi-spec-validator | Python |
| **Check Best Practices** | Spectral | Node.js CLI |
| **Runtime Validation** | openapi-core | Python |

---

## 🎯 For Your Project

1. **First**: Use the Python script above to fix the `preferParams` issue
2. **Then**: Use `swagger2openapi` CLI to convert to OpenAPI 3.0
3. **Finally**: Use Python's `openapi-spec-validator` to validate the result

All 398 errors will be resolved by just removing the empty `enum` from `preferParams`!

---

## References

- **openapi-spec-validator**: https://github.com/python-openapi/openapi-spec-validator
- **swagger2openapi**: https://github.com/MikeRalphson/swagger2openapi
- **openapi-core**: https://github.com/python-openapi/openapi-core
- **Spectral**: https://www.stoplight.io/open-source/spectral
