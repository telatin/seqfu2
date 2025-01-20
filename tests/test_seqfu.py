# test_seqfu.py
import pytest
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, Optional, List
import subprocess
import yaml
from shutil import which
import os

# Test infrastructure
@dataclass
class Dataset:
    """Represents a test dataset with its properties"""
    path: Path
    description: str
    format: str  # fasta/fastq
    compressed: bool
    paired: bool = False
    pair_path: Optional[Path] = None
    expected_sequences: Optional[int] = None

class DatasetManager:
    """Manages test datasets and their properties"""
    def __init__(self):
        self.datasets: Dict[str, Dataset] = {}
        self._load_config()

    def _load_config(self):
        """Load dataset configuration from YAML"""
        config_path = Path(__file__).parent / 'config' / 'datasets.yaml'
        with open(config_path) as f:
            config = yaml.safe_load(f)
            
        # Get base path from config and resolve it relative to config file location
        base_path = Path(config['base_path'])
        if not base_path.is_absolute():
            base_path = (config_path.parent / base_path).resolve()

        for dataset_id, props in config['datasets'].items():
            self.datasets[dataset_id] = Dataset(
                path=base_path / props['path'],
                description=props['description'],
                format=props['format'],
                compressed=props.get('compressed', False),
                paired=props.get('paired', False),
                pair_path=base_path / props['pair_path'] if 'pair_path' in props else None,
                expected_sequences=props.get('expected_sequences')
            )

    def get_dataset(self, dataset_id: str) -> Dataset:
        """Retrieve a dataset by its ID"""
        if dataset_id not in self.datasets:
            raise KeyError(f"Dataset {dataset_id} not found")
        return self.datasets[dataset_id]

def pytest_configure(config):
    """Register custom marks"""
    config.addinivalue_line(
        "markers",
        "slow: mark test as taking a long time to run"
    )

class SeqFuTestBase:
    """Base class for SeqFu tests with helper methods"""
    @staticmethod
    def run_command(binary: Path, args: List[str], input_data: Optional[str] = None, check: bool = True) -> subprocess.CompletedProcess:
        """Run SeqFu command with given arguments"""
        cmd = [str(binary)] + args
        try:
            return subprocess.run(
                cmd,
                input=input_data.encode() if input_data else None,
                capture_output=True,
                text=True,
                check=check
            )
        except subprocess.CalledProcessError as e:
            print(f"Command failed: {' '.join(cmd)}")
            print(f"Output: {e.output}")
            print(f"Error: {e.stderr}")
            raise

    @staticmethod
    def count_sequences(content: str, format_type: str = "fasta") -> int:
        """Count sequences in FASTA/FASTQ content"""
        if format_type.lower() == "fasta":
            return content.count('>')
        elif format_type.lower() == "fastq":
            return content.count('@') // 2
        raise ValueError(f"Unsupported format: {format_type}")

@pytest.fixture(scope="session")
def seqfu_binary():
    """Get seqfu binary from PATH or common locations"""
    # Try PATH first
    binary_path = which("seqfu")
    if binary_path:
        return Path(binary_path)
    
    # Fallback to common locations
    candidates = [
        Path("../bin/seqfu"),
        Path("./seqfu"),
    ]
    
    for path in candidates:
        if path.exists():
            return path.resolve()
            
    raise RuntimeError("seqfu binary not found in PATH or common locations")

@pytest.fixture(scope="session")
def dataset_manager():
    """Fixture providing access to dataset management"""
    return DatasetManager()

# Test classes
class TestBase(SeqFuTestBase):
    """Basic functionality tests that should always pass"""
    
    def test_binary_exists(self, seqfu_binary):
        """Test if SeqFu binary exists and is executable"""
        assert seqfu_binary.exists(), f"Binary not found at {seqfu_binary}"
        assert os.access(seqfu_binary, os.X_OK), f"Binary at {seqfu_binary} is not executable"
    
    def test_version(self, seqfu_binary):
        """Test version command"""
        result = self.run_command(seqfu_binary, ['version'])
        assert result.returncode == 0
        assert result.stdout.strip()

    def test_help_commands(self, seqfu_binary):
        """Test help for all basic commands"""
        commands = ['head', 'tail', 'view', 'qual', 'derep', 'sort', 'count', 'stats']
        for cmd in commands:
            result = self.run_command(seqfu_binary, [cmd, '--help'], check=False)
            assert result.returncode == 0, f"Help failed for command: {cmd}"

class TestDerep(SeqFuTestBase):
    """Tests for sequence dereplication functionality"""
    
    def test_basic_derep(self, seqfu_binary, dataset_manager):
        """Test basic dereplication"""
        dataset = dataset_manager.get_dataset('amplicon')
        assert dataset.path.exists(), f"Test data not found: {dataset.path}"
        result = self.run_command(seqfu_binary, ['derep', str(dataset.path)])
        seq_count = self.count_sequences(result.stdout)
        assert seq_count == dataset.expected_sequences
    
    @pytest.mark.slow
    def test_derep_large_min_size(self, seqfu_binary, dataset_manager):
        """Test dereplication with large minimum size filter"""
        dataset = dataset_manager.get_dataset('amplicon')
        assert dataset.path.exists(), f"Test data not found: {dataset.path}"
        result = self.run_command(seqfu_binary, ['derep', '-m', '10000', str(dataset.path)])
        assert self.count_sequences(result.stdout) == 1