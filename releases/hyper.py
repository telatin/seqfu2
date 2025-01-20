import argparse
import subprocess
import time
import statistics
from typing import List, Tuple

def run_command(command: str) -> float:
    start_time = time.time()
    subprocess.run(command, shell=True, check=True)
    end_time = time.time()
    return end_time - start_time

def benchmark_command(command: str, runs: int) -> List[float]:
    times = []
    for _ in range(runs):
        execution_time = run_command(command)
        times.append(execution_time)
    return times

def calculate_statistics(times: List[float]) -> Tuple[float, float, float, float]:
    mean = statistics.mean(times)
    median = statistics.median(times)
    stdev = statistics.stdev(times) if len(times) > 1 else 0
    min_time = min(times)
    return mean, median, stdev, min_time

def print_results(command: str, times: List[float]):
    mean, median, stdev, min_time = calculate_statistics(times)
    print(f"\nCommand: {command}")
    print(f"Ran {len(times)} times")
    print(f"Mean: {mean:.4f} seconds")
    print(f"Median: {median:.4f} seconds")
    print(f"Standard Deviation: {stdev:.4f} seconds")
    print(f"Minimum: {min_time:.4f} seconds")

def main():
    parser = argparse.ArgumentParser(description="Benchmark one or more commands")
    parser.add_argument("commands", nargs="+", help="Commands to benchmark")
    parser.add_argument("-r", "--runs", type=int, default=10, help="Number of runs for each command")
    args = parser.parse_args()

    for command in args.commands:
        times = benchmark_command(command, args.runs)
        print_results(command, times)

if __name__ == "__main__":
    main()
