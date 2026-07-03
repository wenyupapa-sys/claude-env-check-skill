# Security Policy

## Reporting

Please open a GitHub issue for false positives, false negatives, or unsafe remediation guidance. If a report contains secrets or sensitive local configuration, remove those details before posting publicly.

## Design Rules

- The checker must stay read-only by default.
- Output should mask obvious credentials and tokens.
- Fix guidance should prefer reversible actions and backups.
- Browser-side checks should be described as separate verification, not replaced by local shell checks.
