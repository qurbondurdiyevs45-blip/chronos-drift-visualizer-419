import numpy as np
import json
import os
import sys
from dataclasses import dataclass
from typing import List, Dict, Optional

@dataclass
class DriftMetric:
    node_id: str
    mean_drift_ms: float
    std_dev_ms: float
    max_drift_ms: float
    p95_drift_ms: float
    skewness: float
    samples: int

class DriftAnalyser:
    def __init__(self, raw_data_path: str):
        self.raw_data_path = raw_data_path
        if not os.path.exists(raw_data_path):
            raise FileNotFoundError(f"Log file not found: {raw_data_path}")

    def load_logs(self) -> Dict[str, List[float]]:
        """
        Expects a JSON line file where each line is:
        {"node_id": "string", "drift": float, "timestamp": int}
        """
        node_samples = {}
        with open(self.raw_data_path, 'r') as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    node_id = entry['node_id']
                    drift = entry['drift']
                    if node_id not in node_samples:
                        node_samples[node_id] = []
                    node_samples[node_id].append(float(drift))
                except (json.JSONDecodeError, KeyError):
                    continue
        return node_samples

    def calculate_statistics(self, samples: List[float], node_id: str) -> DriftMetric:
        data = np.array(samples)
        
        # Calculate moments for skewness
        mean = np.mean(data)
        std = np.std(data)
        
        if std > 0:
            skewness = float(np.mean((data - mean)**3) / (std**3))
        else:
            skewness = 0.0

        return DriftMetric(
            node_id=node_id,
            mean_drift_ms=float(mean),
            std_dev_ms=float(std),
            max_drift_ms=float(np.max(data)),
            p95_drift_ms=float(np.percentile(data, 95)),
            skewness=skewness,
            samples=len(data)
        )

    def run(self, output_json: Optional[str] = None):
        raw_data = self.load_logs()
        results = []

        for node_id, drifts in raw_data.items():
            if not drifts:
                continue
            
            metric = self.calculate_statistics(drifts, node_id)
            results.append(metric.__dict__)

            print(f"--- Node: {node_id} ---")
            print(f"  Samples:    {metric.samples}")
            print(f"  Mean Drift: {metric.mean_drift_ms:.6f} ms")
            print(f"  Std Dev:    {metric.std_dev_ms:.6f} ms")
            print(f"  P95 Drift:  {metric.p95_drift_ms:.6f} ms")
            print(f"  Skewness:   {metric.skewness:.4f}")
            print("")

        if output_json:
            with open(output_json, 'w') as f:
                json.dump(results, f, indent=2)
            print(f"Statistical analysis written to {output_json}")

        return results

def main():
    """
    Usage: python process_logs.py <input_log_path> [output_json_path]
    """
    if len(sys.argv) < 2:
        print("Error: No input file specified.")
        print("Usage: python process_logs.py drift_logs.jsonl [analysis_results.json]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        analyser = DriftAnalyser(input_path)
        analyser.run(output_path)
    except Exception as e:
        print(f"Analysis failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()