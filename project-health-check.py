#!/usr/bin/env python3
"""Project Health Check - Comprehensive validation of project health"""
import subprocess
import json
import sys
from pathlib import Path
from datetime import datetime

class ProjectHealthCheck:
    def __init__(self, project_path="."):
        self.project_path = Path(project_path).resolve()
        self.project_name = self.project_path.name
        self.checks_passed = []
        self.warnings = []
        self.errors = []

    def run_all_checks(self):
        """Run all health checks"""
        self.check_containers()
        self.check_networks()
        self.check_configuration()
        self.check_logs()

    def check_containers(self):
        """Check container health"""
        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name],
                capture_output=True, text=True
            )

            if result.returncode != 0:
                self.errors.append(f"Container '{self.project_name}' not found")
                return

            data = json.loads(result.stdout)[0]
            state = data['State']

            if state['Running']:
                self.checks_passed.append(f"{self.project_name}: running")
            else:
                self.errors.append(f"{self.project_name}: not running ({state['Status']})")
                return

            # Uptime
            started = datetime.fromisoformat(state['StartedAt'].replace('Z', '+00:00'))
            uptime = datetime.now(started.tzinfo) - started
            days = uptime.days
            hours = uptime.seconds // 3600
            self.checks_passed.append(f"Uptime: {days} days, {hours} hours")

            # Restart count
            restart_count = state.get('RestartCount', 0)
            if restart_count == 0:
                self.checks_passed.append("No restarts")
            elif restart_count < 3:
                self.warnings.append(f"Container restarted {restart_count} times")
            else:
                self.errors.append(f"Container restarted {restart_count} times (investigate!)")

            # Health check
            health = state.get('Health', {})
            if health:
                status = health.get('Status', 'unknown')
                if status == 'healthy':
                    self.checks_passed.append("Health check: passing")
                elif status == 'starting':
                    self.warnings.append("Health check: still starting")
                else:
                    self.errors.append(f"Health check: {status}")

        except Exception as e:
            self.errors.append(f"Container check failed: {e}")

    def check_networks(self):
        """Check network connectivity"""
        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name,
                 '--format', '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}'],
                capture_output=True, text=True
            )

            if result.returncode == 0:
                networks = result.stdout.strip().split()
                for net in networks:
                    self.checks_passed.append(f"{net}: connected")
        except Exception as e:
            self.warnings.append(f"Network check failed: {e}")

    def check_configuration(self):
        """Check configuration files"""
        # Secrets file
        secrets_file = Path(f"/home/administrator/projects/secrets/{self.project_name}.env")
        if secrets_file.exists():
            self.checks_passed.append(f"Secrets file exists")
        else:
            self.warnings.append(f"Secrets file not found: {secrets_file}")

        # docker-compose.yml
        compose_file = self.project_path / "docker-compose.yml"
        if compose_file.exists():
            self.checks_passed.append("docker-compose.yml exists")
        else:
            self.warnings.append("docker-compose.yml not found")

        # CLAUDE.md
        claude_md = self.project_path / "CLAUDE.md"
        if claude_md.exists():
            self.checks_passed.append("CLAUDE.md exists")
        else:
            self.warnings.append("CLAUDE.md not found (run /validate-claude to create)")

    def check_logs(self):
        """Check recent logs for errors"""
        try:
            result = subprocess.run(
                ['docker', 'logs', self.project_name, '--tail', '100'],
                capture_output=True, text=True
            )

            logs = result.stdout + result.stderr

            error_lines = [l for l in logs.split('\n')
                          if any(x in l.lower() for x in ['error', 'fatal', 'exception'])]

            if len(error_lines) == 0:
                self.checks_passed.append("No errors in last 100 log lines")
            elif len(error_lines) < 5:
                self.warnings.append(f"{len(error_lines)} errors in last 100 lines")
            else:
                self.errors.append(f"{len(error_lines)} errors in last 100 lines (investigate!)")

        except Exception as e:
            self.warnings.append(f"Log check failed: {e}")

    def print_report(self):
        """Print health check report"""
        total = len(self.checks_passed) + len(self.warnings) + len(self.errors)
        health_pct = (len(self.checks_passed) / total * 100) if total > 0 else 0

        print(f"\n=== Project Health Check ===\n")
        print(f"Project: {self.project_name}")
        print(f"Checked: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

        if self.checks_passed:
            print(f"✅ PASSED ({len(self.checks_passed)} checks):")
            for check in self.checks_passed:
                print(f"  ✓ {check}")
            print()

        if self.warnings:
            print(f"⚠️  WARNINGS ({len(self.warnings)} items):")
            for warning in self.warnings:
                print(f"  ⚠ {warning}")
            print()

        if self.errors:
            print(f"❌ ERRORS ({len(self.errors)} critical):")
            for error in self.errors:
                print(f"  ✗ {error}")
            print()

        print(f"Overall Health: {health_pct:.0f}% ({len(self.checks_passed)}/{total} checks passed)")

        if self.errors:
            print("Status: ❌ UNHEALTHY")
            print("Action: Fix critical errors immediately")
        elif self.warnings:
            print("Status: ⚠️  DEGRADED")
            print("Action: Address warnings soon")
        else:
            print("Status: ✅ HEALTHY")
            print("Next check: 24 hours")

if __name__ == "__main__":
    project = sys.argv[1] if len(sys.argv) > 1 else "."
    checker = ProjectHealthCheck(project)
    checker.run_all_checks()
    checker.print_report()
