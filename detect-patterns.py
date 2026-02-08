#!/usr/bin/env python3
"""
Infrastructure Pattern Detector
Identifies common patterns across infrastructure and suggests improvements
"""

import json
import re
import subprocess
import sys
import yaml
from pathlib import Path
from datetime import datetime

class PatternDetector:
    def __init__(self, project_path="."):
        self.project_path = Path(project_path).resolve()
        self.project_name = self.project_path.name
        self.claude_md = self.project_path / "CLAUDE.md"
        self.compose_file = self.project_path / "docker-compose.yml"
        self.secrets_file = Path(f"/home/administrator/projects/secrets/{self.project_name}.env")

        self.patterns = {
            "oauth2": {"score": 0, "max": 10, "found": [], "missing": []},
            "database": {"score": 0, "max": 8, "found": [], "missing": []},
            "monitoring": {"score": 0, "max": 6, "found": [], "missing": []},
            "ssl_tls": {"score": 0, "max": 5, "found": [], "missing": []},
            "health_check": {"score": 0, "max": 4, "found": [], "missing": []},
            "backup": {"score": 0, "max": 3, "found": [], "missing": []}
        }

        self.suggestions = []

    def detect_all(self):
        """Run all pattern detection"""

        if not self.claude_md.exists() and not self.compose_file.exists():
            print(f"No CLAUDE.md or docker-compose.yml found for {self.project_name}")
            return

        # Load compose file
        self.compose_data = None
        if self.compose_file.exists():
            with open(self.compose_file) as f:
                self.compose_data = yaml.safe_load(f)

        # Load CLAUDE.md
        self.claude_content = ""
        if self.claude_md.exists():
            self.claude_content = self.claude_md.read_text()

        # Load secrets
        self.secrets_content = ""
        if self.secrets_file.exists():
            self.secrets_content = self.secrets_file.read_text()

        # Detect patterns
        self.detect_oauth2_pattern()
        self.detect_database_pattern()
        self.detect_monitoring_pattern()
        self.detect_ssl_tls_pattern()
        self.detect_health_check_pattern()
        self.detect_backup_pattern()

        # Generate suggestions
        self.generate_suggestions()

    def detect_oauth2_pattern(self):
        """Detect OAuth2/SSO integration pattern"""
        pattern = self.patterns["oauth2"]

        if not self.compose_data:
            return

        networks = set()
        for service_name, service in self.compose_data.get('services', {}).items():
            if 'networks' in service:
                for network in service['networks']:
                    if isinstance(network, str):
                        networks.add(network)

        # Check for 3-network pattern
        if 'traefik-net' in networks:
            pattern["score"] += 2
            pattern["found"].append("Connected to traefik-net")
        else:
            pattern["missing"].append("Not connected to traefik-net (required for external access)")

        if 'oauth2-net' in networks:
            pattern["score"] += 2
            pattern["found"].append("Connected to oauth2-net")
        else:
            pattern["missing"].append("Not using oauth2-net (consider OAuth2 proxy)")

        if 'keycloak-net' in networks:
            pattern["score"] += 2
            pattern["found"].append("Connected to keycloak-net (direct OIDC)")
        elif 'oauth2-net' not in networks:
            pattern["missing"].append("Not using Keycloak SSO")

        # Check for oauth2-proxy container
        has_oauth2_proxy = False
        for service_name in self.compose_data.get('services', {}).keys():
            if 'oauth2-proxy' in service_name or 'auth-proxy' in service_name:
                pattern["score"] += 2
                pattern["found"].append(f"Uses {service_name} for authentication")
                has_oauth2_proxy = True
                break

        # Check for OIDC environment variables
        has_oidc_config = False
        if self.secrets_content:
            oidc_vars = ['OIDC_', 'OAUTH2_', 'KEYCLOAK_']
            if any(var in self.secrets_content for var in oidc_vars):
                pattern["score"] += 1
                pattern["found"].append("OIDC configuration present")
                has_oidc_config = True

        if not has_oidc_config and not has_oauth2_proxy:
            pattern["missing"].append("No OAuth2/OIDC configuration found")

        # Check documentation
        if self.claude_content:
            if 'oauth2' in self.claude_content.lower() or 'keycloak' in self.claude_content.lower():
                pattern["score"] += 1
                pattern["found"].append("SSO documented in CLAUDE.md")
            elif has_oauth2_proxy or has_oidc_config:
                pattern["missing"].append("SSO configured but not documented")

    def detect_database_pattern(self):
        """Detect database integration pattern"""
        pattern = self.patterns["database"]

        if not self.compose_data:
            return

        # Detect database technology
        db_found = None
        for service_name, service in self.compose_data.get('services', {}).items():
            image = service.get('image', '').lower()
            if 'postgres' in image:
                db_found = 'PostgreSQL'
                break
            elif 'mysql' in image:
                db_found = 'MySQL'
                break
            elif 'mongo' in image:
                db_found = 'MongoDB'
                break
            elif 'redis' in image:
                db_found = 'Redis'
                break

        if not db_found:
            # Check networks for external database
            networks = set()
            for service_name, service in self.compose_data.get('services', {}).items():
                if 'networks' in service:
                    for network in service['networks']:
                        if isinstance(network, str):
                            networks.add(network)

            if 'db-net' in networks:
                pattern["score"] += 2
                pattern["found"].append("Connected to db-net (external database)")
                db_found = "External"
            else:
                return  # No database integration

        if db_found:
            pattern["score"] += 2
            pattern["found"].append(f"Uses {db_found}")

        # Check for connection pooling
        if self.secrets_content:
            pool_vars = ['POOL_SIZE', 'MAX_CONNECTIONS', 'CONNECTION_POOL']
            if any(var in self.secrets_content for var in pool_vars):
                pattern["score"] += 1
                pattern["found"].append("Connection pooling configured")
            else:
                pattern["missing"].append("No connection pooling configuration (recommended for production)")

        # Check for backup configuration
        if self.claude_content:
            if 'backup' in self.claude_content.lower():
                pattern["score"] += 1
                pattern["found"].append("Backup documented")
            else:
                pattern["missing"].append("Database backup not documented")

        # Check for migration strategy
        if self.claude_content:
            migration_keywords = ['migration', 'schema', 'prisma', 'alembic', 'flyway']
            if any(kw in self.claude_content.lower() for kw in migration_keywords):
                pattern["score"] += 1
                pattern["found"].append("Schema migration documented")
            else:
                pattern["missing"].append("Schema migration strategy not documented")

        # Check for secrets management
        if self.secrets_file.exists():
            pattern["score"] += 1
            pattern["found"].append("Database credentials in secrets file")
        else:
            pattern["missing"].append("No secrets file found")

        # Check for health check
        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name],
                capture_output=True, text=True
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)[0]
                if 'Health' in data['State']:
                    pattern["score"] += 1
                    pattern["found"].append("Container health check configured")
        except Exception:
            pass

    def detect_monitoring_pattern(self):
        """Detect monitoring/logging integration pattern"""
        pattern = self.patterns["monitoring"]

        if not self.compose_data:
            return

        # Check for Loki logging labels
        has_loki_labels = False
        for service_name, service in self.compose_data.get('services', {}).items():
            labels = service.get('labels', {})
            if isinstance(labels, dict):
                for key in labels.keys():
                    if 'logging' in key or 'loki' in key:
                        pattern["score"] += 2
                        pattern["found"].append("Loki logging labels configured")
                        has_loki_labels = True
                        break
            if has_loki_labels:
                break

        if not has_loki_labels:
            pattern["missing"].append("No Loki logging labels (recommended for centralized logging)")

        # Check for Prometheus metrics
        has_metrics = False
        if self.secrets_content:
            if 'METRICS' in self.secrets_content or 'PROMETHEUS' in self.secrets_content:
                pattern["score"] += 1
                pattern["found"].append("Metrics configuration found")
                has_metrics = True

        if not has_metrics and self.claude_content:
            if 'metrics' in self.claude_content.lower() or 'prometheus' in self.claude_content.lower():
                pattern["score"] += 1
                pattern["found"].append("Metrics mentioned in documentation")
                has_metrics = True

        if not has_metrics:
            pattern["missing"].append("No metrics/Prometheus configuration")

        # Check for Grafana dashboards
        if self.claude_content:
            if 'grafana' in self.claude_content.lower() or 'dashboard' in self.claude_content.lower():
                pattern["score"] += 1
                pattern["found"].append("Grafana dashboard documented")
            else:
                pattern["missing"].append("No Grafana dashboard mentioned")

        # Check for log retention
        if self.claude_content:
            if 'log' in self.claude_content.lower():
                pattern["score"] += 1
                pattern["found"].append("Logging documented")
            else:
                pattern["missing"].append("Logging strategy not documented")

        # Check for alerting
        if self.claude_content:
            if 'alert' in self.claude_content.lower():
                pattern["score"] += 1
                pattern["found"].append("Alerting documented")

    def detect_ssl_tls_pattern(self):
        """Detect SSL/TLS configuration pattern"""
        pattern = self.patterns["ssl_tls"]

        # Check for HTTPS URLs
        if self.claude_content:
            https_urls = re.findall(r'https://([a-z0-9-]+\.ai-servicers\.com)', self.claude_content)
            if https_urls:
                pattern["score"] += 2
                pattern["found"].append(f"HTTPS endpoint: {https_urls[0]}")
            else:
                pattern["missing"].append("No HTTPS endpoint documented")

        # Check for Traefik TLS configuration
        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name],
                capture_output=True, text=True
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)[0]
                labels = data['Config'].get('Labels', {})

                has_tls = False
                for key, value in labels.items():
                    if 'tls' in key.lower() or 'certresolver' in key.lower():
                        pattern["score"] += 2
                        pattern["found"].append("Traefik TLS configuration present")
                        has_tls = True
                        break

                if not has_tls:
                    pattern["missing"].append("No Traefik TLS labels found")
        except Exception:
            pass

        # Check for security headers
        if self.claude_content:
            security_keywords = ['hsts', 'security header', 'csp', 'x-frame-options']
            if any(kw in self.claude_content.lower() for kw in security_keywords):
                pattern["score"] += 1
                pattern["found"].append("Security headers documented")

    def detect_health_check_pattern(self):
        """Detect health check configuration"""
        pattern = self.patterns["health_check"]

        if not self.compose_data:
            return

        # Check docker-compose.yml for healthcheck
        has_healthcheck = False
        for service_name, service in self.compose_data.get('services', {}).items():
            if 'healthcheck' in service:
                pattern["score"] += 2
                pattern["found"].append("Health check defined in docker-compose.yml")
                has_healthcheck = True
                break

        if not has_healthcheck:
            pattern["missing"].append("No health check in docker-compose.yml (recommended)")

        # Check for health endpoint
        if self.claude_content:
            health_keywords = ['/health', '/healthz', '/ping', 'health check', 'health endpoint']
            if any(kw in self.claude_content.lower() for kw in health_keywords):
                pattern["score"] += 1
                pattern["found"].append("Health endpoint documented")
            elif has_healthcheck:
                pattern["missing"].append("Health check configured but not documented")

        # Check actual container health
        try:
            result = subprocess.run(
                ['docker', 'inspect', self.project_name, '--format', '{{.State.Health.Status}}'],
                capture_output=True, text=True
            )
            health = result.stdout.strip()
            if health == 'healthy':
                pattern["score"] += 1
                pattern["found"].append("Container currently healthy")
        except Exception:
            pass

    def detect_backup_pattern(self):
        """Detect backup configuration"""
        pattern = self.patterns["backup"]

        if self.claude_content:
            if 'backup' in self.claude_content.lower():
                pattern["score"] += 2
                pattern["found"].append("Backup strategy documented")
            else:
                pattern["missing"].append("No backup strategy documented")

        # Check for backup scripts
        backup_script = self.project_path / "backup.sh"
        if backup_script.exists():
            pattern["score"] += 1
            pattern["found"].append("Backup script present")
        else:
            pattern["missing"].append("No backup script found")

    def generate_suggestions(self):
        """Generate improvement suggestions based on detected patterns"""

        # OAuth2 pattern suggestions
        oauth2 = self.patterns["oauth2"]
        if oauth2["score"] < oauth2["max"] * 0.7:  # Less than 70%
            if "Not using oauth2-net" in str(oauth2["missing"]):
                self.suggestions.append({
                    "priority": "medium",
                    "category": "Security",
                    "suggestion": "Add OAuth2 authentication using oauth2-proxy",
                    "example": "See obsidian-api or litellm for OAuth2 integration examples"
                })

        # Database pattern suggestions
        db = self.patterns["database"]
        if db["score"] > 0:  # Has database
            if "No connection pooling" in str(db["missing"]):
                self.suggestions.append({
                    "priority": "high",
                    "category": "Performance",
                    "suggestion": "Add connection pooling configuration",
                    "example": "Set POOL_SIZE=10-20 in secrets file"
                })
            if "Database backup not documented" in str(db["missing"]):
                self.suggestions.append({
                    "priority": "high",
                    "category": "Data Safety",
                    "suggestion": "Document database backup strategy",
                    "example": "Add backup procedure to CLAUDE.md Operations section"
                })

        # Monitoring pattern suggestions
        mon = self.patterns["monitoring"]
        if mon["score"] < mon["max"] * 0.5:  # Less than 50%
            if "No Loki logging labels" in str(mon["missing"]):
                self.suggestions.append({
                    "priority": "medium",
                    "category": "Observability",
                    "suggestion": "Add Loki logging labels for centralized logging",
                    "example": "Add to docker-compose.yml:\n  labels:\n    logging: \"promtail\"\n    logging_jobname: \"containerized_app\""
                })

        # Health check suggestions
        health = self.patterns["health_check"]
        if health["score"] < health["max"] * 0.5:
            self.suggestions.append({
                "priority": "high",
                "category": "Reliability",
                "suggestion": "Add health check to docker-compose.yml",
                "example": "healthcheck:\n  test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:3000/health\"]\n  interval: 30s\n  timeout: 10s\n  retries: 3"
            })

    def print_report(self):
        """Print pattern detection report"""

        print(f"\n=== Pattern Analysis for {self.project_name} ===\n")
        print(f"Analyzed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

        # Show detected patterns
        print("✅ Detected Patterns:\n")
        for pattern_name, pattern in self.patterns.items():
            percentage = (pattern["score"] / pattern["max"] * 100) if pattern["max"] > 0 else 0
            emoji = "✅" if percentage >= 70 else "⚠️" if percentage >= 40 else "❌"

            print(f"{emoji} {pattern_name.replace('_', ' ').title()}: {percentage:.0f}% ({pattern['score']}/{pattern['max']})")

            if pattern["found"]:
                for item in pattern["found"][:3]:  # Show first 3
                    print(f"  ✓ {item}")

            if pattern["missing"]:
                for item in pattern["missing"][:2]:  # Show first 2
                    print(f"  ✗ {item}")

            print()

        # Show suggestions
        if self.suggestions:
            print(f"💡 Suggested Improvements ({len(self.suggestions)} items):\n")

            # Group by priority
            high = [s for s in self.suggestions if s["priority"] == "high"]
            medium = [s for s in self.suggestions if s["priority"] == "medium"]
            low = [s for s in self.suggestions if s["priority"] == "low"]

            for priority_list, priority_name in [(high, "High Priority"), (medium, "Medium Priority"), (low, "Low Priority")]:
                if priority_list:
                    print(f"  {priority_name}:")
                    for sug in priority_list:
                        print(f"    • [{sug['category']}] {sug['suggestion']}")
                        if 'example' in sug:
                            print(f"      Example: {sug['example']}")
                        print()
        else:
            print("💡 No suggestions - patterns look good!\n")

        # Overall score
        total_score = sum(p["score"] for p in self.patterns.values())
        total_max = sum(p["max"] for p in self.patterns.values())
        overall = (total_score / total_max * 100) if total_max > 0 else 0

        print(f"Overall Pattern Score: {overall:.0f}% ({total_score}/{total_max})")

        if overall >= 80:
            print("Status: ✅ EXCELLENT - Following best practices")
        elif overall >= 60:
            print("Status: ✅ GOOD - Most patterns implemented")
        elif overall >= 40:
            print("Status: ⚠️  FAIR - Consider implementing more patterns")
        else:
            print("Status: ❌ NEEDS WORK - Many patterns missing")

        print()

if __name__ == "__main__":
    project = sys.argv[1] if len(sys.argv) > 1 else "."

    detector = PatternDetector(project)
    detector.detect_all()
    detector.print_report()
