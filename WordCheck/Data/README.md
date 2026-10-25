# Local dictionary resources

Supply your own licensed, UTF-8 word lists here before building the iOS app:

- `NWL2023.txt`: NASPA NWL 2023, 196,601 unique entries.
- `CSW24.txt`: Collins CSW 2024, 280,887 unique entries.

Entries must be uppercase, separated by whitespace. The app checks the expected unique-entry count and fails closed if resources are missing or corrupt. These files are intentionally excluded from Git. Permission to distribute dictionaries inside an app does not automatically permit publishing the raw word lists in a public repository.

The Swift package's core tests run without these resources. The real-dictionary integration test requires a locally built app bundle; see the root README.
