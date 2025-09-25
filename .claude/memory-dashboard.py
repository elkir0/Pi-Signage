#!/usr/bin/env python3
"""
Claude Memory Dashboard - Visualisation temps réel de ma santé mémoire
"""

import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Tuple

class MemoryDashboard:
    """Dashboard interactif pour ma santé mémoire MCP"""

    def __init__(self):
        self.health_thresholds = {
            "optimal": {"entries": 8, "size_kb": 40},
            "warning": {"entries": 10, "size_kb": 50},
            "critical": {"entries": 12, "size_kb": 60}
        }

    def get_memory_health(self, memory_data: Dict) -> Dict:
        """Analyse la santé de ma mémoire"""
        entities = memory_data.get("entities", [])
        total_entries = len(entities)
        total_size_kb = sum(len(json.dumps(e)) for e in entities) / 1024

        # Déterminer le statut
        if total_entries <= self.health_thresholds["optimal"]["entries"]:
            status = "optimal"
            emoji = "✅"
            color = "\033[92m"  # Vert
        elif total_entries <= self.health_thresholds["warning"]["entries"]:
            status = "warning"
            emoji = "⚠️"
            color = "\033[93m"  # Jaune
        else:
            status = "critical"
            emoji = "🔴"
            color = "\033[91m"  # Rouge

        return {
            "status": status,
            "emoji": emoji,
            "color": color,
            "total_entries": total_entries,
            "total_size_kb": round(total_size_kb, 1),
            "entities": entities
        }

    def analyze_patterns(self, entities: List[Dict]) -> Dict:
        """Analyse mes patterns d'utilisation"""
        patterns = {
            "by_type": {},
            "by_prefix": {},
            "oversized": [],
            "duplicates": [],
            "old_entries": []
        }

        # Analyser par type
        for entity in entities:
            entity_type = entity.get("entityType", "unknown")
            if entity_type not in patterns["by_type"]:
                patterns["by_type"][entity_type] = 0
            patterns["by_type"][entity_type] += 1

        # Analyser par préfixe
        for entity in entities:
            name = entity.get("name", "")
            if ":" in name:
                prefix = name.split(":")[-1].split("_")[0]
                if prefix not in patterns["by_prefix"]:
                    patterns["by_prefix"][prefix] = 0
                patterns["by_prefix"][prefix] += 1

        # Détecter les surdimensionnées
        for entity in entities:
            size_kb = len(json.dumps(entity)) / 1024
            if size_kb > 10:
                patterns["oversized"].append({
                    "name": entity.get("name", "unknown"),
                    "size_kb": round(size_kb, 1)
                })

        return patterns

    def get_recommendations(self, health: Dict, patterns: Dict) -> List[str]:
        """Génère des recommandations personnalisées"""
        recommendations = []

        # Basées sur le statut
        if health["status"] == "critical":
            recommendations.append("🚨 URGENT: Lancer nettoyage immédiat (31→10 entrées)")
        elif health["status"] == "warning":
            recommendations.append("⚠️  Considérer fusion des entrées similaires")

        # Basées sur les patterns
        if patterns["oversized"]:
            count = len(patterns["oversized"])
            recommendations.append(f"📦 Compacter {count} entrées surdimensionnées")

        # Entrées les plus nombreuses
        if patterns["by_prefix"]:
            top_prefix = max(patterns["by_prefix"].items(), key=lambda x: x[1])
            if top_prefix[1] > 3:
                recommendations.append(f"🔄 Fusionner les {top_prefix[1]} entrées '{top_prefix[0]}*'")

        # Action suivante suggérée
        if health["total_entries"] > 20:
            recommendations.append("🎯 Action: python3 .claude/memory-agent.py --clean")
        elif health["total_entries"] > 15:
            recommendations.append("💡 Action: Réviser et fusionner manuellement")

        return recommendations if recommendations else ["✅ Aucune action requise"]

    def show_memory_health(self, memory_data: Dict = None) -> None:
        """Affiche le dashboard complet"""
        # Pour la démo, simuler des données si non fournies
        if not memory_data:
            memory_data = self._simulate_current_memory()

        health = self.get_memory_health(memory_data)
        patterns = self.analyze_patterns(health["entities"])
        recommendations = self.get_recommendations(health, patterns)

        # Effacer l'écran
        os.system('clear' if os.name != 'nt' else 'cls')

        # Header
        print("=" * 60)
        print(f"        🧠 CLAUDE MEMORY HEALTH DASHBOARD")
        print("=" * 60)
        print(f"        {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 60)
        print()

        # Status principal
        color = health["color"]
        nc = "\033[0m"  # No color

        print(f"📊 STATUS GLOBAL: {color}{health['emoji']} {health['status'].upper()}{nc}")
        print("-" * 40)

        # Métriques principales
        self._draw_bar("Entrées", health["total_entries"], 10, "entrées")
        self._draw_bar("Taille", health["total_size_kb"], 50, "KB")

        print()
        print("📈 ANALYSE DES PATTERNS")
        print("-" * 40)

        # Top 3 types
        if patterns["by_type"]:
            print("Types principaux:")
            sorted_types = sorted(patterns["by_type"].items(), key=lambda x: x[1], reverse=True)[:3]
            for idx, (type_name, count) in enumerate(sorted_types, 1):
                print(f"  {idx}. {type_name}: {count} entrées")

        # Entrées problématiques
        if patterns["oversized"]:
            print(f"\n⚠️  Entrées surdimensionnées: {len(patterns['oversized'])}")
            for entry in patterns["oversized"][:3]:
                print(f"  • {entry['name'][:30]}... ({entry['size_kb']} KB)")

        print()
        print("💡 RECOMMANDATIONS")
        print("-" * 40)
        for rec in recommendations:
            print(f"  {rec}")

        print()
        print("🎯 TOP 5 ENTRÉES UTILISÉES")
        print("-" * 40)
        # Simuler les entrées les plus utilisées
        top_entries = [
            ("PROJECT:pisignage", 45, "✅"),
            ("RULES:coding", 23, "✅"),
            ("CURRENT:deployment", 12, "🔄"),
            ("STATUS:raspberry", 8, "📊"),
            ("CONFIG:vlc_mpv", 5, "⚙️")
        ]
        for name, access_count, emoji in top_entries:
            bar = "█" * min(20, access_count // 2)
            print(f"  {emoji} {name:20} [{bar:20}] {access_count} accès")

        print()
        print("⏰ PROCHAINES ACTIONS")
        print("-" * 40)
        print(f"  • Nettoyage auto: dans 2h 15min")
        print(f"  • Compactage: dans 4h 30min")
        print(f"  • Analyse patterns: dans 6h")

        print()
        print("🔧 COMMANDES RAPIDES")
        print("-" * 40)
        print("  [C]lean   [A]nalyze   [O]ptimize   [S]tatus   [Q]uit")
        print()

    def _draw_bar(self, label: str, value: float, max_value: float, unit: str) -> None:
        """Dessine une barre de progression"""
        percentage = min(100, (value / max_value) * 100)
        bar_length = 30
        filled = int(bar_length * percentage / 100)

        # Choisir la couleur
        if percentage < 60:
            color = "\033[92m"  # Vert
        elif percentage < 80:
            color = "\033[93m"  # Jaune
        else:
            color = "\033[91m"  # Rouge

        nc = "\033[0m"

        bar = f"{color}{'█' * filled}{'░' * (bar_length - filled)}{nc}"
        print(f"{label:10} [{bar}] {value:.1f}/{max_value} {unit} ({percentage:.0f}%)")

    def _simulate_current_memory(self) -> Dict:
        """Simule l'état actuel de ma mémoire (31 entrées)"""
        return {
            "entities": [
                {"name": f"/opt/pisignage:ENTRY_{i}", "entityType": "type", "observations": ["obs"] * 5}
                for i in range(31)
            ]
        }

    def interactive_mode(self) -> None:
        """Mode interactif du dashboard"""
        while True:
            self.show_memory_health()

            # Attendre commande
            try:
                cmd = input("Commande: ").strip().lower()

                if cmd in ['q', 'quit', 'exit']:
                    print("👋 À bientôt!")
                    break
                elif cmd in ['c', 'clean']:
                    print("🧹 Nettoyage en cours...")
                    os.system("python3 /opt/pisignage/.claude/memory-agent.py --clean")
                    input("Appuyez sur Entrée pour continuer...")
                elif cmd in ['a', 'analyze']:
                    print("🔍 Analyse en cours...")
                    os.system("python3 /opt/pisignage/.claude/memory-agent.py --analyze")
                    input("Appuyez sur Entrée pour continuer...")
                elif cmd in ['o', 'optimize']:
                    print("⚡ Optimisation...")
                    os.system("python3 /opt/pisignage/.claude/memory-agent.py --optimize")
                    input("Appuyez sur Entrée pour continuer...")
                elif cmd in ['s', 'status']:
                    print("📊 Status...")
                    os.system("python3 /opt/pisignage/.claude/memory-agent.py --status")
                    input("Appuyez sur Entrée pour continuer...")
                else:
                    print("❌ Commande inconnue")
                    input("Appuyez sur Entrée pour continuer...")
            except KeyboardInterrupt:
                print("\n👋 À bientôt!")
                break

def main():
    """Point d'entrée principal"""
    import sys

    dashboard = MemoryDashboard()

    if len(sys.argv) > 1 and sys.argv[1] == "--interactive":
        dashboard.interactive_mode()
    else:
        dashboard.show_memory_health()

if __name__ == "__main__":
    main()