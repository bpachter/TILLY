#!/usr/bin/env python3
"""
TILLY Balance Analysis Tool
Deterministic combat simulation sweep for crew trait effectiveness analysis.
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from collections import defaultdict

class BalanceAnalyzer:
    def __init__(self, tilly_root: Path):
        self.tilly_root = Path(tilly_root).resolve()
        self.data_dir = self.tilly_root / "data" / "examples"
        self.run_results = {
            "total_runs": 0,
            "victories": 0,
            "defeats": 0,
            "avg_hull_remaining": 0.0,
            "crew_traits_effectiveness": defaultdict(lambda: {"wins": 0, "losses": 0}),
            "enemy_stats": defaultdict(lambda: {"wins": 0, "losses": 0}),
        }
        
        # Verify data directory exists
        if not self.data_dir.exists():
            print(f"ERROR: Data directory not found: {self.data_dir}")
            raise FileNotFoundError(f"Data directory not found: {self.data_dir}")
    
    def load_contracts(self):
        """Load game data contracts."""
        self.contracts = {}
        
        for contract_file in ["crew_traits.json", "crew_archetypes.json", "enemy_templates.json", "events.json"]:
            file_path = self.data_dir / contract_file
            if file_path.exists():
                with open(file_path) as f:
                    self.contracts[contract_file.replace(".json", "")] = json.load(f)
        
        print(f"✓ Loaded {len(self.contracts)} contracts")
    
    def analyze_trait_pool(self):
        """Analyze crew trait distribution."""
        traits = self.contracts.get("crew_traits", {}).get("traits", [])
        archetypes = self.contracts.get("crew_archetypes", {}).get("archetypes", [])
        
        print("\n=== CREW TRAIT DISTRIBUTION ===")
        print(f"Total traits available: {len(traits)}")
        
        trait_categories = defaultdict(list)
        for trait in traits:
            category = trait.get("category", "unknown")
            trait_categories[category].append(trait.get("id", "unknown"))
        
        for category, trait_list in sorted(trait_categories.items()):
            print(f"  {category}: {', '.join(trait_list)}")
        
        print(f"\nArchetype trait pools:")
        for archetype in archetypes:
            pool = archetype.get("trait_pool", [])
            print(f"  {archetype.get('role', 'unknown')}: {len(pool)} traits")
    
    def simulate_combat_outcome(self, seed: int) -> dict:
        """
        Simulate a single combat encounter.
        Returns: {"outcome": "victory|defeat", "hull_remaining": int, "crew_traits": [str]}
        """
        # Placeholder: In production, this would call Godot engine or Python combat simulator
        # For now, we'll generate synthetic outcomes based on seed patterns
        
        import random
        random.seed(seed)
        
        # Simulate crew trait selection (random from available traits)
        traits = self.contracts.get("crew_traits", {}).get("traits", [])
        selected_traits = random.sample([t.get("id") for t in traits], min(3, len(traits)))
        
        # Base win probability
        base_win_prob = 0.5
        
        # Trait bonuses (these should match the Godot implementation)
        trait_bonuses = {
            "calm_under_fire": 0.1,
            "brave_heart": 0.12,
            "hyperfocus": 0.05,
            "suspicious": 0.08,
            "curious_explorer": 0.03,
            "reckless_genius": 0.06,
            "cautious": -0.05,
            "pessimist": -0.08,
        }
        
        for trait in selected_traits:
            base_win_prob += trait_bonuses.get(trait, 0.0)
        
        base_win_prob = max(0.1, min(0.9, base_win_prob))  # Clamp to 10-90%
        
        # Simulate outcome
        outcome = "victory" if random.random() < base_win_prob else "defeat"
        hull_remaining = random.randint(20, 100) if outcome == "victory" else random.randint(0, 20)
        
        return {
            "outcome": outcome,
            "hull_remaining": hull_remaining,
            "crew_traits": selected_traits,
            "win_prob": base_win_prob
        }
    
    def run_simulation_sweep(self, num_runs: int = 1000):
        """Run deterministic simulations."""
        print(f"\n=== RUNNING {num_runs} SIMULATIONS ===")
        
        victories = 0
        defeats = 0
        total_hull = 0
        
        for i in range(num_runs):
            result = self.simulate_combat_outcome(i)
            
            if result["outcome"] == "victory":
                victories += 1
                total_hull += result["hull_remaining"]
            else:
                defeats += 1
            
            # Track trait effectiveness
            for trait in result["crew_traits"]:
                if result["outcome"] == "victory":
                    self.run_results["crew_traits_effectiveness"][trait]["wins"] += 1
                else:
                    self.run_results["crew_traits_effectiveness"][trait]["losses"] += 1
            
            if (i + 1) % 100 == 0:
                print(f"  Progress: {i + 1}/{num_runs} runs completed")
        
        self.run_results["total_runs"] = num_runs
        self.run_results["victories"] = victories
        self.run_results["defeats"] = defeats
        self.run_results["avg_hull_remaining"] = total_hull / max(1, victories)
        
        return self.run_results
    
    def print_analysis(self):
        """Print comprehensive balance analysis."""
        print("\n=== BALANCE ANALYSIS RESULTS ===")
        print(f"Total runs: {self.run_results['total_runs']}")
        print(f"Victories: {self.run_results['victories']} ({self.run_results['victories'] / max(1, self.run_results['total_runs']) * 100:.1f}%)")
        print(f"Defeats: {self.run_results['defeats']} ({self.run_results['defeats'] / max(1, self.run_results['total_runs']) * 100:.1f}%)")
        
        if self.run_results['victories'] > 0:
            print(f"Average hull remaining (victories): {self.run_results['avg_hull_remaining']:.1f}")
        
        print("\n=== TRAIT EFFECTIVENESS ===")
        trait_effectiveness = []
        for trait_id, stats in self.run_results["crew_traits_effectiveness"].items():
            total = stats["wins"] + stats["losses"]
            if total > 0:
                win_rate = stats["wins"] / total * 100
                trait_effectiveness.append((trait_id, win_rate, stats["wins"], total))
        
        # Sort by win rate
        trait_effectiveness.sort(key=lambda x: x[1], reverse=True)
        
        for trait_id, win_rate, wins, total in trait_effectiveness:
            print(f"  {trait_id:25s}: {win_rate:5.1f}% ({wins}/{total})")
        
        # Balance recommendations
        print("\n=== BALANCE RECOMMENDATIONS ===")
        win_rate = self.run_results['victories'] / max(1, self.run_results['total_runs'])
        
        if win_rate > 0.75:
            print("⚠ Player win rate too high (>75%)")
            print("  → Increase enemy hull or damage")
            print("  → Add more challenging enemy types")
        elif win_rate < 0.25:
            print("⚠ Player win rate too low (<25%)")
            print("  → Decrease enemy damage")
            print("  → Increase crew trait bonuses")
        else:
            print("✓ Win rate balanced (25-75% range)")
        
        # Trait imbalance detection
        traits_above_60 = [t for t, wr, _, _ in trait_effectiveness if wr > 60]
        traits_below_40 = [t for t, wr, _, _ in trait_effectiveness if wr < 40]
        
        if traits_above_60:
            print(f"\n⚠ Overpowered traits (>60%): {', '.join(traits_above_60)}")
        
        if traits_below_40:
            print(f"\n⚠ Underpowered traits (<40%): {', '.join(traits_below_40)}")
        
        if not traits_above_60 and not traits_below_40:
            print("\n✓ All traits within acceptable effectiveness range (40-60%)")


def main():
    # Find TILLY root directory
    script_dir = Path(__file__).resolve().parent
    tilly_root = script_dir.parent.parent  # tools/analysis/../../
    
    print(f"TILLY root: {tilly_root}")
    
    analyzer = BalanceAnalyzer(tilly_root)
    analyzer.load_contracts()
    analyzer.analyze_trait_pool()
    
    # Run simulations
    num_runs = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    analyzer.run_simulation_sweep(num_runs)
    analyzer.print_analysis()
    
    print("\n=== ANALYSIS COMPLETE ===")


if __name__ == "__main__":
    main()
