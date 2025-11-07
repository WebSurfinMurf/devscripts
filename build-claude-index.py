#!/usr/bin/env python3
"""
CLAUDE.md Index Builder
Scans all projects and builds searchable JSON index
"""

import json
import re
import sys
import yaml
from pathlib import Path
from datetime import datetime

class CLAUDEIndexBuilder:
    def __init__(self, projects_root="/home/administrator/projects"):
        self.projects_root = Path(projects_root)
        self.index_file = self.projects_root / ".claude-index.json"
        self.index = {
            "generated": datetime.now().isoformat(),
            "projects_count": 0,
            "projects": {}
        }

    def build(self, specific_project=None):
        """Build index for all projects or specific project"""

        if specific_project:
            # Update just one project
            project_path = self.projects_root / specific_project
            if project_path.exists():
                # Load existing index
                if self.index_file.exists():
                    with open(self.index_file) as f:
                        self.index = json.load(f)

                self._index_project(project_path)
                self.index["generated"] = datetime.now().isoformat()
                self.index["projects_count"] = len(self.index["projects"])
            else:
                print(f"Error: Project '{specific_project}' not found")
                return
        else:
            # Build full index
            for project_dir in sorted(self.projects_root.iterdir()):
                if not project_dir.is_dir():
                    continue

                # Skip special directories
                if project_dir.name in ["admin", "data", "devscripts", ".claude"]:
                    continue

                self._index_project(project_dir)

            self.index["projects_count"] = len(self.index["projects"])

        # Save index
        with open(self.index_file, 'w') as f:
            json.dump(self.index, f, indent=2)

        print(f"✅ Index built: {self.index['projects_count']} projects")
        print(f"📍 Saved to: {self.index_file}")

    def _index_project(self, project_path):
        """Index a single project"""
        project_name = project_path.name

        project_data = {
            "name": project_name,
            "path": str(project_path),
            "status": "unknown",
            "purpose": "",
            "technologies": [],
            "networks": [],
            "dependencies": [],
            "urls": [],
            "ports": [],
            "tags": [],
            "has_claude_md": False,
            "has_docker_compose": False
        }

        # Parse CLAUDE.md if exists
        claude_md = project_path / "CLAUDE.md"
        if claude_md.exists():
            project_data["has_claude_md"] = True
            self._parse_claude_md(claude_md, project_data)

        # Parse docker-compose.yml if exists
        compose_file = project_path / "docker-compose.yml"
        if compose_file.exists():
            project_data["has_docker_compose"] = True
            self._parse_docker_compose(compose_file, project_data)

        # Add project to index
        self.index["projects"][project_name] = project_data

    def _parse_claude_md(self, claude_md_path, project_data):
        """Extract metadata from CLAUDE.md"""
        content = claude_md_path.read_text()

        # Extract status
        status_match = re.search(r'\*\*Status\*\*:\s*([✅🚧⏸️🔴⚠️])\s*(\w+)', content)
        if status_match:
            status_text = status_match.group(2).lower()
            project_data["status"] = status_text

            # Map emoji to status
            emoji = status_match.group(1)
            if emoji == "✅":
                project_data["tags"].append("production")
            elif emoji == "🚧":
                project_data["tags"].append("development")
            elif emoji == "⏸️":
                project_data["tags"].append("paused")

        # Extract purpose
        purpose_match = re.search(r'\*\*Purpose\*\*:\s*(.+)', content)
        if purpose_match:
            project_data["purpose"] = purpose_match.group(1).strip()

        # Extract URLs
        url_patterns = [
            r'https://([a-z0-9-]+\.ai-servicers\.com)',
            r'\*\*URL\*\*:\s*(https?://[^\s\)]+)',
        ]
        for pattern in url_patterns:
            urls = re.findall(pattern, content)
            for url in urls:
                if url.startswith('http'):
                    if url not in project_data["urls"]:
                        project_data["urls"].append(url)
                else:
                    full_url = f"https://{url}"
                    if full_url not in project_data["urls"]:
                        project_data["urls"].append(full_url)

        # Extract technologies from content
        tech_keywords = {
            "postgresql": ["postgres", "postgresql", "psql"],
            "redis": ["redis"],
            "mongodb": ["mongodb", "mongo"],
            "mysql": ["mysql"],
            "nginx": ["nginx"],
            "traefik": ["traefik"],
            "keycloak": ["keycloak", "sso", "oauth2"],
            "docker": ["docker", "docker-compose"],
            "python": ["python", "flask", "fastapi", "django"],
            "nodejs": ["node", "nodejs", "express", "npm"],
            "typescript": ["typescript", "ts"],
            "javascript": ["javascript", "js"],
            "react": ["react"],
            "vue": ["vue"],
            "grafana": ["grafana"],
            "loki": ["loki"],
            "prometheus": ["prometheus"],
            "minio": ["minio", "s3"],
        }

        content_lower = content.lower()
        for tech, keywords in tech_keywords.items():
            if any(keyword in content_lower for keyword in keywords):
                if tech not in project_data["technologies"]:
                    project_data["technologies"].append(tech)

        # Extract networks
        network_match = re.findall(r'([a-z0-9-]+)-net(?:work)?', content_lower)
        for net in network_match:
            network_name = f"{net}-net"
            if network_name not in project_data["networks"]:
                project_data["networks"].append(network_name)

    def _parse_docker_compose(self, compose_path, project_data):
        """Extract metadata from docker-compose.yml"""
        try:
            with open(compose_path) as f:
                compose = yaml.safe_load(f)

            if not compose:
                return

            # Extract networks
            if "networks" in compose:
                for service_name, service in compose.get("services", {}).items():
                    if "networks" in service:
                        for network in service["networks"]:
                            if isinstance(network, str):
                                if network not in project_data["networks"]:
                                    project_data["networks"].append(network)

            # Extract ports
            for service_name, service in compose.get("services", {}).items():
                if "ports" in service:
                    for port_mapping in service["ports"]:
                        if isinstance(port_mapping, str):
                            # Parse "8080:80" format
                            parts = port_mapping.split(":")
                            if len(parts) >= 2:
                                external_port = parts[0]
                                if external_port not in project_data["ports"]:
                                    project_data["ports"].append(external_port)

            # Extract image-based technologies
            for service_name, service in compose.get("services", {}).items():
                image = service.get("image", "")

                # Detect technologies from image names
                if "postgres" in image:
                    if "postgresql" not in project_data["technologies"]:
                        project_data["technologies"].append("postgresql")
                if "redis" in image:
                    if "redis" not in project_data["technologies"]:
                        project_data["technologies"].append("redis")
                if "mongo" in image:
                    if "mongodb" not in project_data["technologies"]:
                        project_data["technologies"].append("mongodb")
                if "nginx" in image:
                    if "nginx" not in project_data["technologies"]:
                        project_data["technologies"].append("nginx")
                if "node" in image:
                    if "nodejs" not in project_data["technologies"]:
                        project_data["technologies"].append("nodejs")
                if "python" in image:
                    if "python" not in project_data["technologies"]:
                        project_data["technologies"].append("python")

        except Exception as e:
            # Silently skip invalid YAML files
            pass

if __name__ == "__main__":
    # Check for --project flag
    specific_project = None
    if len(sys.argv) >= 3 and sys.argv[1] == "--project":
        specific_project = sys.argv[2]

    builder = CLAUDEIndexBuilder()
    builder.build(specific_project)
