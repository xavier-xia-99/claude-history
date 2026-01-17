---
name: cargo-all
description: "Runs comprehensive Rust development checks: cargo fmt (format), cargo check (quick compile check), cargo clippy (lints), cargo test (tests), and cargo run --release (execute). Use when you want to validate and run the entire Rust project."
---

# Cargo All - Comprehensive Rust Validation

Runs all essential Rust development commands in sequence to format, check, lint, test, and run your project.

## What This Skill Does

This skill runs the following cargo commands in order:

1. **cargo fmt** - Format code according to rustfmt rules
2. **cargo check** - Fast compilation check without producing binaries
3. **cargo clippy** - Run Clippy lints for code quality
4. **cargo test** - Run all tests
5. **cargo run --release** - Build and run the application in release mode

## When to Use This Skill

Use this skill when you want to:
- Validate the entire project after making changes
- Ensure code quality before committing
- Run a full development cycle check
- Prepare for deployment or PR submission

## How to Use

When the user invokes this skill (e.g., "run /cargo-all"), execute the following commands in sequence:

### Step 1: Format Code
```bash
cargo fmt
```

### Step 2: Quick Compile Check
```bash
cargo check
```

### Step 3: Run Clippy Lints
```bash
cargo clippy --all-targets --all-features
```

### Step 4: Run Tests
```bash
cargo test
```

### Step 5: Build and Run in Release Mode
```bash
cargo run --release
```

## Important Notes

- **Order matters**: Format first, then check compilation, then lint, then test, finally run
- **Stop on failure**: If any command fails, report the error to the user before continuing
- **Release mode**: The final run uses `--release` for optimized performance
- **All features**: Clippy runs with `--all-targets --all-features` for comprehensive linting

## Error Handling

If any step fails:
1. Report which command failed
2. Show the error output
3. Ask the user if they want to:
   - Fix the issue and continue
   - Skip to the next command
   - Stop the skill execution

## Example Output

```
✓ cargo fmt - Code formatted
✓ cargo check - Compilation check passed
✓ cargo clippy - No lint warnings
✓ cargo test - All tests passed (12 tests)
✓ cargo run --release - Application running...
```
