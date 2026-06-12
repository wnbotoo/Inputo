# Security Policy

Inputo handles provider credentials, clipboard writes, local app activation, and future grant-scoped file access. Please report security issues privately so maintainers can investigate before details are public.

## Supported Versions

Inputo has not reached a stable public release yet. Security fixes are handled on the `main` branch until versioned releases are published.

| Version | Supported |
| --- | --- |
| `main` | Yes |
| Released versions | Not yet available |

## Reporting a Vulnerability

Use GitHub private vulnerability reporting for this repository when available. If private reporting is not available, contact a maintainer through the repository owner profile and ask for a private disclosure channel before sharing exploit details.

Please include:

- affected commit, branch, or release
- macOS version and Inputo build method
- clear reproduction steps
- impact and security boundary crossed
- whether secrets, prompts, generated text, local paths, or private screenshots are involved

Please do not include real API keys, private prompts, generated confidential text, or screenshots of sensitive content. Use redacted examples whenever possible.

## What Counts as Security-Sensitive

Examples include:

- API key exposure outside Keychain or redacted settings summaries
- Web composer access to provider credentials or direct provider networking
- automatic paste, clipboard writes, app activation, or file operations without explicit user action
- bridge policy bypasses or unexpected native tool execution
- leakage of prompts, generated output, local file paths, screenshots, window titles, or target-control contents
- denial-of-service issues that leave the app unable to cancel provider requests or recover cleanly

## Response Expectations

Maintainers aim to acknowledge private reports within 7 days, confirm severity after reproduction, and coordinate a fix before public disclosure. Timelines may vary before the project has a formal maintainer rotation.

## Safe Harbor

Good-faith research is welcome when it avoids privacy harm, data destruction, persistence, social engineering, and access to accounts or systems you do not own. Stop testing and report privately if you encounter secrets or private user data.
