#!/usr/bin/env python3
"""
CLAUDE.md Drift Detector
Compares CLAUDE.md documentation vs actual deployment reality
"""

import json
import re
import subprocess
import sys
import yaml
from pathlib import Path
from datetime import datetime

class CLAUDEDiffChecker:
    def __init__(self, project_path="."):
        self.project_path = Path(project_path).resolve()
        self.project_name = self.project_path.name
        self.claude_md = self.project_path / "CLAUDE.md"
        self.compose_file = self.project_path / "docker-compose.yml"

        self.matches = []
        self.warnings = []
        self.errors = []

    def check_all(self):
        """Run all drift checks"""

        if not self.claude_md.exists():
            self.errors.append("CLAUDE.md not found")
            return

        self.claude_content = self.claude_md.read_text()

        # Load compose file if exists
        self.compose_data = None
        if self.compose_file.exists():
            with open(self.compose_file) as f:
                self.compose_data = yaml.safe_load(f)

        # Run checks
        self.check_urls()
        self.check_networks()
        self.check_ports()
        self.check_container_status()
        self.check_technologies()
        self.check_dependencies()
        self.check_traefik_routes()

    def check_urls(self):
        """Check if documented URLs match Traefik configuration"""

        # Extract URLs from CLAUDE.md
        doc_urls = set(re.findall(r'https://([a-z0-9-]+\.ai-servicers\.com)', self.claude_content))

        if not doc_urls:
            return

        # Check if container exists
        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                self.warnings.append("Container not running, cannot verify URLs")
                return

            data = json.loads(result.stdout)[0]
            labels = data['Config'].get('Labels', {})

            # Check Traefik rules
            traefik_urls = set()
            for key, value in labels.items():
                if 'traefik.http.routers' in key and '.rule' in key:
                    # Extract hostname from rule like "Host(`example.ai-servicers.com`)"
                    match = re.search(r'Host\(`([^`]+)`\)', value)
                    if match:
                        traefik_urls.add(match.group(1))

            if traefik_urls:
                # Compare
                if doc_urls == traefik_urls:
                    self.matches.append(f"URLs match Traefik configuration: {', '.join(doc_urls)}")
                else:
                    missing_in_docs = traefik_urls - doc_urls
                    missing_in_traefik = doc_urls - traefik_urls

                    if missing_in_docs:
                        self.warnings.append(f"Traefik has URLs not in CLAUDE.md: {', '.join(missing_in_docs)}")
                    if missing_in_traefik:
                        self.warnings.append(f"CLAUDE.md has URLs not in Traefik: {', '.join(missing_in_traefik)}")
        except Exception as e:
            self.warnings.append(f"Could not verify URLs: {e}")

    def check_networks(self):
        """Check if documented networks match docker-compose.yml"""

        # Extract networks from CLAUDE.md
        doc_networks = set(re.findall(r'([a-z0-9-]+)-net(?:work)?', self.claude_content.lower()))
        doc_networks = {f"{n}-net" for n in doc_networks}

        if not self.compose_data:
            return

        # Get networks from docker-compose.yml
        compose_networks = set()
        for service_name, service in self.compose_data.get('services', {}).items():
            if 'networks' in service:
                for network in service['networks']:
                    if isinstance(network, str):
                        compose_networks.add(network)
                    elif isinstance(network, dict):
                        compose_networks.update(network.keys())

        if not compose_networks:
            return

        # Compare
        if doc_networks == compose_networks:
            self.matches.append(f"Networks match docker-compose.yml: {', '.join(sorted(compose_networks))}")
        else:
            missing_in_docs = compose_networks - doc_networks
            missing_in_compose = doc_networks - compose_networks

            if missing_in_docs:
                self.warnings.append(f"docker-compose.yml has networks not documented: {', '.join(missing_in_docs)}")
            if missing_in_compose:
                self.warnings.append(f"CLAUDE.md documents networks not in docker-compose.yml: {', '.join(missing_in_compose)}")

    def check_ports(self):
        """Check if documented ports match docker-compose.yml"""

        # Extract ports from CLAUDE.md
        doc_ports = set(re.findall(r'(?:port|Port|PORT)\s*[:\s]+(\d{4,5})', self.claude_content))

        if not self.compose_data:
            return

        # Get ports from docker-compose.yml
        compose_ports = set()
        for service_name, service in self.compose_data.get('services', {}).items():
            if 'ports' in service:
                for port_mapping in service['ports']:
                    if isinstance(port_mapping, str):
                        # Parse "8080:80" format
                        parts = port_mapping.split(':')
                        if len(parts) >= 2:
                            compose_ports.add(parts[0])
                    elif isinstance(port_mapping, int):
                        compose_ports.add(str(port_mapping))

        if not compose_ports and not doc_ports:
            return

        # Compare
        if doc_ports and compose_ports:
            if doc_ports == compose_ports:
                self.matches.append(f"Ports match docker-compose.yml: {', '.join(sorted(compose_ports))}")
            else:
                missing_in_docs = compose_ports - doc_ports
                missing_in_compose = doc_ports - compose_ports

                if missing_in_docs:
                    self.warnings.append(f"docker-compose.yml exposes ports not documented: {', '.join(missing_in_docs)}")
                if missing_in_compose:
                    self.warnings.append(f"CLAUDE.md documents ports not in docker-compose.yml: {', '.join(missing_in_compose)}")
        elif compose_ports:
            self.warnings.append(f"docker-compose.yml has ports but none documented: {', '.join(compose_ports)}")

    def check_container_status(self):
        """Check if status emoji matches container health"""

        # Extract status from CLAUDE.md
        status_match = re.search(r'\*\*Status\*\*:\s*([✅🚧⏸️🔴⚠️])', self.claude_content)
        if not status_match:
            return

        doc_emoji = status_match.group(1)

        # Check container status
        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name, '--format', '{{.State.Status}}'],
                capture_output=True, text=True
            )

            if result.returncode != 0:
                if doc_emoji == "⏸️":
                    self.matches.append("Status ⏸️ (Paused) matches - container not running")
                else:
                    self.warnings.append(f"Status shows {doc_emoji} but container not found")
                return

            container_status = result.stdout.strip()

            # Map container status to expected emoji
            if container_status == "running":
                # Check health if available
                health_result = subprocess.run(
                    ['docker', 'inspect', self.project_name, '--format', '{{.State.Health.Status}}'],
                    capture_output=True, text=True
                )
                health_status = health_result.stdout.strip()

                if health_status == "healthy" or not health_status:
                    if doc_emoji == "✅":
                        self.matches.append("Status ✅ (Production) matches - container running and healthy")
                    elif doc_emoji == "🚧":
                        self.matches.append("Status 🚧 (Development) - container running")
                    else:
                        self.warnings.append(f"Container running/healthy but status shows {doc_emoji}")
                else:
                    if doc_emoji in ["⚠️", "🔴"]:
                        self.matches.append(f"Status {doc_emoji} matches - container unhealthy")
                    else:
                        self.warnings.append(f"Container unhealthy ({health_status}) but status shows {doc_emoji}")
            else:
                if doc_emoji == "⏸️":
                    self.matches.append(f"Status ⏸️ matches - container {container_status}")
                else:
                    self.warnings.append(f"Container {container_status} but status shows {doc_emoji}")

        except Exception as e:
            self.warnings.append(f"Could not verify container status: {e}")

    def check_technologies(self):
        """Check if documented technologies match images"""

        if not self.compose_data:
            return

        # Get images from docker-compose.yml
        compose_techs = set()
        for service_name, service in self.compose_data.get('services', {}).items():
            image = service.get('image', '')

            # Detect technologies
            if 'postgres' in image.lower():
                compose_techs.add('PostgreSQL')
            if 'redis' in image.lower():
                compose_techs.add('Redis')
            if 'mongo' in image.lower():
                compose_techs.add('MongoDB')
            if 'mysql' in image.lower():
                compose_techs.add('MySQL')
            if 'nginx' in image.lower():
                compose_techs.add('Nginx')
            if 'node' in image.lower():
                compose_techs.add('Node.js')
            if 'python' in image.lower():
                compose_techs.add('Python')

        if not compose_techs:
            return

        # Check if mentioned in CLAUDE.md
        content_lower = self.claude_content.lower()
        found_techs = set()
        missing_techs = set()

        for tech in compose_techs:
            if tech.lower() in content_lower:
                found_techs.add(tech)
            else:
                missing_techs.add(tech)

        if found_techs:
            self.matches.append(f"Technologies documented: {', '.join(sorted(found_techs))}")

        if missing_techs:
            self.warnings.append(f"Technologies used but not documented: {', '.join(sorted(missing_techs))}")

    def check_dependencies(self):
        """Check if documented dependencies match docker-compose.yml"""

        if not self.compose_data:
            return

        # Get dependencies from docker-compose.yml
        compose_deps = set()
        for service_name, service in self.compose_data.get('services', {}).items():
            if 'depends_on' in service:
                deps = service['depends_on']
                if isinstance(deps, list):
                    compose_deps.update(deps)
                elif isinstance(deps, dict):
                    compose_deps.update(deps.keys())

        if not compose_deps:
            return

        # Check if mentioned in CLAUDE.md
        content_lower = self.claude_content.lower()
        found_deps = set()
        missing_deps = set()

        for dep in compose_deps:
            if dep.lower() in content_lower:
                found_deps.add(dep)
            else:
                missing_deps.add(dep)

        if found_deps:
            self.matches.append(f"Dependencies documented: {', '.join(sorted(found_deps))}")

        if missing_deps:
            self.warnings.append(f"Dependencies in docker-compose.yml not documented: {', '.join(sorted(missing_deps))}")

    def check_traefik_routes(self):
        """Check Traefik routing configuration"""

        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name],
                capture_output=True, text=True
            )

            if result.returncode != 0:
                return

            data = json.loads(result.stdout)[0]
            labels = data['Config'].get('Labels', {})

            # Check for Traefik labels
            has_traefik = any('traefik' in key for key in labels.keys())

            if has_traefik:
                # Check if Traefik is mentioned in CLAUDE.md
                if 'traefik' in self.claude_content.lower():
                    self.matches.append("Traefik routing configured and documented")
                else:
                    self.warnings.append("Container has Traefik labels but not documented in CLAUDE.md")

        except Exception:
            pass

    def print_report(self):
        """Print drift detection report"""

        total = len(self.matches) + len(self.warnings) + len(self.errors)

        print(f"\n=== CLAUDE.md Drift Report for {self.project_name} ===\n")
        print(f"Checked: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

        if self.matches:
            print(f"✅ MATCHES ({len(self.matches)} items):")
            for match in self.matches:
                print(f"  ✓ {match}")
            print()

        if self.warnings:
            print(f"⚠️  DRIFT DETECTED ({len(self.warnings)} items):")
            for warning in self.warnings:
                print(f"  ⚠ {warning}")
            print()

        if self.errors:
            print(f"❌ ERRORS ({len(self.errors)} items):")
            for error in self.errors:
                print(f"  ✗ {error}")
            print()

        if total == 0:
            print("No checks could be performed (missing files?)\n")
            return 1

        # Calculate drift score
        drift_score = (len(self.warnings) + len(self.errors) * 2) / total * 100 if total > 0 else 0

        print(f"Drift Score: {drift_score:.0f}% ({len(self.warnings) + len(self.errors)}/{total} mismatches)")

        if drift_score == 0:
            print("Status: ✅ PERFECT SYNC")
            print("Recommendation: Documentation matches deployment perfectly!")
        elif drift_score < 20:
            print("Status: ✅ GOOD")
            print("Recommendation: Minor drift detected, consider updating CLAUDE.md")
        elif drift_score < 50:
            print("Status: ⚠️  MODERATE DRIFT")
            print("Recommendation: Update CLAUDE.md to reflect actual deployment")
        else:
            print("Status: ❌ SIGNIFICANT DRIFT")
            print("Recommendation: CLAUDE.md needs major updates to match reality")

        print()

        return 0 if drift_score < 50 else 1

if __name__ == "__main__":
    project = sys.argv[1] if len(sys.argv) > 1 else "."

    checker = CLAUDEDiffChecker(project)
    checker.check_all()
    exit_code = checker.print_report()
    sys.exit(exit_code)
