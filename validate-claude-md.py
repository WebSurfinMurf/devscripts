#!/usr/bin/env python3
"""
CLAUDE.md Validation Script
Checks CLAUDE.md files for completeness, quality, and adherence to style guide
"""

import re
import sys
from pathlib import Path
from datetime import datetime, timedelta

class CLAUDEMDValidator:
    REQUIRED_SECTIONS = [
        "Quick Start",
        "Architecture",
        "Operations",
        "Recent Changes"
    ]

    RECOMMENDED_SECTIONS = [
        "Security",
        "Troubleshooting",
        "Related Services",
        "Dependencies"
    ]

    def __init__(self, project_path="."):
        self.project_path = Path(project_path).resolve()
        self.claude_md = self.project_path / "CLAUDE.md"

        self.passed = []
        self.warnings = []
        self.errors = []
        self.suggestions = []

    def validate(self):
        """Run all validations"""

        if not self.claude_md.exists():
            self.errors.append("CLAUDE.md file not found")
            return

        self.content = self.claude_md.read_text()

        self.check_header()
        self.check_sections()
        self.check_content_quality()
        self.check_references()
        self.check_security()
        self.check_age()
        self.check_best_practices()

    def check_header(self):
        """Validate header has required fields"""

        # Status with emoji
        if re.search(r'\*\*Status\*\*:\s*[✅🚧⏸️🔴⚠️]', self.content):
            self.passed.append("Status field present with emoji")
        else:
            self.errors.append("Missing Status field with emoji (✅🚧⏸️🔴⚠️)")

        # Version
        if re.search(r'\*\*Version\*\*:', self.content):
            self.passed.append("Version field present")
        else:
            self.errors.append("Missing Version field")

        # Purpose
        if re.search(r'\*\*Purpose\*\*:', self.content):
            purpose_match = re.search(r'\*\*Purpose\*\*:\s*(.+)', self.content)
            if purpose_match:
                purpose = purpose_match.group(1).strip()

                if 20 <= len(purpose) <= 200:
                    self.passed.append("Purpose is clear and concise")
                elif len(purpose) < 20:
                    self.warnings.append("Purpose seems too short, add more detail")
                else:
                    self.warnings.append("Purpose is very long, consider making it concise")
        else:
            self.errors.append("Missing Purpose field")

        # Last Updated
        if re.search(r'\*\*Last Updated\*\*:', self.content):
            self.passed.append("Last Updated field present")
        else:
            self.warnings.append("Missing Last Updated field")

    def check_sections(self):
        """Check for required sections"""

        for section in self.REQUIRED_SECTIONS:
            pattern = f"## {section}"
            if re.search(pattern, self.content):
                self.passed.append(f"Section '{section}' present")
            else:
                self.errors.append(f"Missing required section: ## {section}")

        for section in self.RECOMMENDED_SECTIONS:
            pattern = f"## {section}"
            if not re.search(pattern, self.content):
                self.suggestions.append(f"Consider adding '## {section}' section")

    def check_content_quality(self):
        """Check content quality"""

        # Check for deploy command
        if re.search(r'\.\/deploy\.sh|docker compose up', self.content):
            self.passed.append("Deploy command documented")
        else:
            self.warnings.append("No deploy command found in documentation")

        # Check for common operations
        operations_section = re.search(
            r'## Operations(.*?)(?=##|$)',
            self.content,
            re.DOTALL
        )
        if operations_section:
            ops_content = operations_section.group(1)

            if 'docker logs' in ops_content or 'logs -f' in ops_content:
                self.passed.append("Log viewing command documented")
            else:
                self.warnings.append("No log viewing command in Operations")

            if 'restart' in ops_content:
                self.passed.append("Restart command documented")
            else:
                self.warnings.append("No restart command in Operations")

    def check_references(self):
        """Validate file and path references"""

        # Check docker-compose.yml reference
        if 'docker-compose.yml' in self.content or 'docker compose' in self.content:
            compose_file = self.project_path / "docker-compose.yml"
            if compose_file.exists():
                self.passed.append("docker-compose.yml exists as referenced")
            else:
                self.errors.append("References docker-compose.yml but file not found")

        # Check deploy.sh reference
        if './deploy.sh' in self.content:
            deploy_script = self.project_path / "deploy.sh"
            if deploy_script.exists():
                if deploy_script.stat().st_mode & 0o111:  # Executable
                    self.passed.append("deploy.sh exists and is executable")
                else:
                    self.warnings.append("deploy.sh exists but is not executable")
            else:
                self.errors.append("References deploy.sh but file not found")

        # Check secrets path format
        secrets_refs = re.findall(r'/home/administrator/secrets/([^/\s]+)', self.content)
        if secrets_refs:
            for secret_file in secrets_refs:
                if re.match(r'^[a-z0-9-]+\.env$', secret_file):
                    self.passed.append(f"Secrets path format correct: {secret_file}")
                else:
                    self.warnings.append(
                        f"Secrets file '{secret_file}' doesn't follow naming convention"
                    )

        # Check infrastructure CLAUDE.md reference
        if '/home/administrator/projects/CLAUDE.md' in self.content:
            self.passed.append("References infrastructure CLAUDE.md")
        else:
            self.warnings.append(
                "Missing reference to infrastructure CLAUDE.md at end of file"
            )

    def check_security(self):
        """Check for security issues"""

        # Check for hardcoded passwords/secrets
        dangerous_patterns = [
            (r'password["\']?\s*[=:]\s*["\'][^"\']{8,}["\']', 'Possible hardcoded password'),
            (r'api[_-]?key["\']?\s*[=:]\s*["\'][^"\']{10,}["\']', 'Possible hardcoded API key'),
            (r'secret["\']?\s*[=:]\s*["\'][^"\']{10,}["\']', 'Possible hardcoded secret'),
        ]

        for pattern, message in dangerous_patterns:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            if matches:
                # Check if it's in a code block showing example/template
                for match in matches:
                    if any(placeholder in match.lower() for placeholder in
                          ['<password>', 'changeme', 'your-', 'example', '{password}', '$password']):
                        continue  # Likely a template
                    self.errors.append(f"SECURITY: {message} found in documentation")

        # HTTP vs HTTPS
        http_urls = re.findall(r'http://(?!localhost|127\.0\.0\.1|[a-z-]+:\d+)[^\s\)]+', self.content)
        if http_urls:
            for url in http_urls[:3]:  # Limit to first 3
                self.warnings.append(f"Found HTTP URL (prefer HTTPS): {url}")

    def check_age(self):
        """Check how old the documentation is"""

        last_updated_match = re.search(
            r'\*\*Last Updated\*\*:\s*(\d{4}-\d{2}-\d{2})',
            self.content
        )

        if last_updated_match:
            date_str = last_updated_match.group(1)
            try:
                last_updated = datetime.strptime(date_str, '%Y-%m-%d')
                age_days = (datetime.now() - last_updated).days

                if age_days == 0:
                    self.passed.append(f"Last Updated: today (fresh! ✨)")
                elif age_days < 7:
                    self.passed.append(f"Last Updated: {age_days} days ago (recent)")
                elif age_days < 30:
                    self.warnings.append(
                        f"Last Updated: {age_days} days ago (consider updating)"
                    )
                elif age_days < 90:
                    self.warnings.append(
                        f"Last Updated: {age_days} days ago (needs update)"
                    )
                else:
                    self.errors.append(
                        f"Last Updated: {age_days} days ago (STALE - update required)"
                    )
            except ValueError:
                self.warnings.append("Last Updated date format invalid (should be YYYY-MM-DD)")

    def check_best_practices(self):
        """Check for best practices"""

        # Code block formatting
        code_blocks = re.findall(r'```(\w*)\n', self.content)
        if code_blocks:
            has_language = any(lang for lang in code_blocks)
            if has_language:
                self.passed.append("Code blocks specify language")
            else:
                self.warnings.append("Some code blocks missing language specification")

        # Recent Changes updated
        recent_changes = re.search(
            r'## Recent Changes(.*?)(?=##|$)',
            self.content,
            re.DOTALL
        )
        if recent_changes:
            changes_content = recent_changes.group(1)
            # Find most recent date
            dates = re.findall(r'### (\d{4}-\d{2}-\d{2})', changes_content)
            if dates:
                most_recent = max(dates)
                recent_date = datetime.strptime(most_recent, '%Y-%m-%d')
                days_since = (datetime.now() - recent_date).days

                if days_since < 7:
                    self.passed.append("Recent Changes section is up to date")
                else:
                    self.suggestions.append(
                        f"Recent Changes last entry is {days_since} days old - "
                        "consider adding update"
                    )

    def print_report(self):
        """Print validation report"""

        total_checks = len(self.passed) + len(self.warnings) + len(self.errors)
        score = (len(self.passed) / total_checks * 100) if total_checks > 0 else 0

        print("\n=== CLAUDE.md Validation ===\n")
        print(f"Project: {self.project_path.name}")
        print(f"File: {self.claude_md}\n")

        if self.passed:
            print(f"✅ PASSED ({len(self.passed)} checks):")
            for item in self.passed:
                print(f"  ✓ {item}")
            print()

        if self.warnings:
            print(f"⚠️  WARNINGS ({len(self.warnings)} items):")
            for item in self.warnings:
                print(f"  ⚠ {item}")
            print()

        if self.errors:
            print(f"❌ ERRORS ({len(self.errors)} critical):")
            for item in self.errors:
                print(f"  ✗ {item}")
            print()

        if self.suggestions:
            print(f"💡 SUGGESTIONS:")
            for item in self.suggestions:
                print(f"  - {item}")
            print()

        print(f"Overall Score: {len(self.passed)}/{total_checks} ({score:.0f}%)")

        if score >= 90:
            print("Grade: EXCELLENT ✅")
            print("Recommendation: Documentation is production-ready!")
        elif score >= 75:
            print("Grade: GOOD ⚠️")
            print("Recommendation: Address warnings, nearly ready for production")
        elif score >= 50:
            print("Grade: NEEDS WORK 🔧")
            print("Recommendation: Fix errors before using in production")
        else:
            print("Grade: POOR ❌")
            print("Recommendation: Major revisions needed")

        return 0 if score >= 75 else 1

if __name__ == "__main__":
    project = sys.argv[1] if len(sys.argv) > 1 else "."

    validator = CLAUDEMDValidator(project)
    validator.validate()
    exit_code = validator.print_report()
    sys.exit(exit_code)
