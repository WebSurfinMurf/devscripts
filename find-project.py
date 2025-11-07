#!/usr/bin/env python3
"""
Project Finder - Search CLAUDE.md index for projects
"""

import json
import sys
from pathlib import Path
from datetime import datetime

class ProjectFinder:
    def __init__(self):
        self.index_file = Path("/home/administrator/projects/.claude-index.json")

        if not self.index_file.exists():
            print("❌ Index not found. Building index...")
            import subprocess
            subprocess.run([
                "python3",
                "/home/administrator/projects/devscripts/build-claude-index.py"
            ])

        with open(self.index_file) as f:
            self.index = json.load(f)

    def search(self, search_term=None):
        """Search projects by term"""

        if not search_term:
            # List all projects
            self._list_all()
            return

        # Check for special search syntax
        if "status:" in search_term.lower():
            status = search_term.split(":", 1)[1].strip()
            self._search_by_status(status)
            return

        # General search across all fields
        matches = []
        search_lower = search_term.lower()

        for project_name, project in self.index["projects"].items():
            match_reason = None

            # Search in name
            if search_lower in project_name.lower():
                match_reason = f"Project name contains '{search_term}'"

            # Search in purpose
            elif search_lower in project.get("purpose", "").lower():
                match_reason = f"Purpose: {project['purpose'][:60]}..."

            # Search in technologies
            elif any(search_lower in tech.lower() for tech in project.get("technologies", [])):
                matching_techs = [t for t in project["technologies"] if search_lower in t.lower()]
                match_reason = f"Uses technology: {', '.join(matching_techs)}"

            # Search in networks
            elif any(search_lower in net.lower() for net in project.get("networks", [])):
                matching_nets = [n for n in project["networks"] if search_lower in n.lower()]
                match_reason = f"Connected to: {', '.join(matching_nets)}"

            # Search in URLs
            elif any(search_lower in url.lower() for url in project.get("urls", [])):
                match_reason = "URL matches search"

            # Search in tags
            elif any(search_lower in tag.lower() for tag in project.get("tags", [])):
                matching_tags = [t for t in project["tags"] if search_lower in t.lower()]
                match_reason = f"Tagged: {', '.join(matching_tags)}"

            if match_reason:
                matches.append((project_name, project, match_reason))

        # Display results
        if not matches:
            print(f"\n❌ No projects found matching '{search_term}'\n")
            print("Try searching for:")
            print("  - Technology: postgres, redis, nodejs, python")
            print("  - Network: traefik-net, oauth2-net, db-net")
            print("  - Purpose: api, monitoring, auth, database")
            print("  - Status: status:production, status:development")
            return

        print(f"\n=== Found {len(matches)} project{'s' if len(matches) != 1 else ''} matching '{search_term}' ===\n")

        for i, (name, project, reason) in enumerate(matches, 1):
            # Status emoji
            status_emoji = "❓"
            status = project.get("status", "unknown")
            if status == "production" or "production" in project.get("tags", []):
                status_emoji = "✅"
            elif status == "development" or "development" in project.get("tags", []):
                status_emoji = "🚧"
            elif status == "paused" or "paused" in project.get("tags", []):
                status_emoji = "⏸️"

            print(f"{i}. {name} ({status_emoji} {status.title()})")

            if project.get("purpose"):
                print(f"   Purpose: {project['purpose']}")

            if project.get("technologies"):
                tech_str = ", ".join(project["technologies"][:5])
                if len(project["technologies"]) > 5:
                    tech_str += f" (+{len(project['technologies']) - 5} more)"
                print(f"   Tech: {tech_str}")

            if project.get("urls"):
                print(f"   URL: {project['urls'][0]}")

            print(f"   Match: {reason}")
            print(f"   Path: {project['path']}")
            print()

        # Show index age
        generated = datetime.fromisoformat(self.index["generated"])
        age = datetime.now() - generated
        age_str = f"{age.seconds // 3600} hours ago" if age.days == 0 else f"{age.days} days ago"
        print(f"Index: {self.index['projects_count']} projects (updated {age_str})")
        print()

    def _search_by_status(self, status):
        """Search projects by status"""
        matches = []

        for project_name, project in self.index["projects"].items():
            if status.lower() in project.get("status", "").lower():
                matches.append((project_name, project))
            elif status.lower() in [tag.lower() for tag in project.get("tags", [])]:
                matches.append((project_name, project))

        if not matches:
            print(f"\n❌ No projects found with status '{status}'\n")
            return

        print(f"\n=== Found {len(matches)} project{'s' if len(matches) != 1 else ''} with status '{status}' ===\n")

        for name, project in matches:
            status_emoji = "✅" if status.lower() == "production" else "🚧" if status.lower() == "development" else "⏸️"
            print(f"• {name} ({status_emoji})")
            if project.get("purpose"):
                print(f"  {project['purpose'][:70]}")
            print()

    def _list_all(self):
        """List all indexed projects"""
        print(f"\n=== {self.index['projects_count']} Indexed Projects ===\n")

        # Group by status
        by_status = {
            "production": [],
            "development": [],
            "paused": [],
            "unknown": []
        }

        for name, project in self.index["projects"].items():
            status = project.get("status", "unknown")
            if "production" in project.get("tags", []):
                status = "production"
            elif "development" in project.get("tags", []):
                status = "development"
            elif "paused" in project.get("tags", []):
                status = "paused"

            by_status[status].append((name, project))

        # Display by status
        if by_status["production"]:
            print(f"✅ Production ({len(by_status['production'])}):")
            for name, project in sorted(by_status["production"]):
                purpose = project.get("purpose", "")[:50]
                print(f"  • {name:<25} {purpose}")
            print()

        if by_status["development"]:
            print(f"🚧 Development ({len(by_status['development'])}):")
            for name, project in sorted(by_status["development"]):
                purpose = project.get("purpose", "")[:50]
                print(f"  • {name:<25} {purpose}")
            print()

        if by_status["paused"]:
            print(f"⏸️  Paused ({len(by_status['paused'])}):")
            for name, project in sorted(by_status["paused"]):
                purpose = project.get("purpose", "")[:50]
                print(f"  • {name:<25} {purpose}")
            print()

        print(f"Use '/find-project <term>' to search")
        print()

if __name__ == "__main__":
    search_term = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else None

    finder = ProjectFinder()
    finder.search(search_term)
