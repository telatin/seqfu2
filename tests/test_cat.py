# test_cat.py
import pytest
from pathlib import Path
from test_seqfu import (
    SeqFuTestBase,
    seqfu_binary,
    dataset_manager,
    Dataset
)


class TestCat(SeqFuTestBase):
    """Tests for the cat command"""
    
    def test_input_sequence_count(self, seqfu_binary, dataset_manager):
        """Test that numbers.fa has 1000 sequences"""
        dataset = dataset_manager.get_dataset('numbers')
        assert dataset.path.exists(), f"Test data not found: {dataset.path}"
        result = self.run_command(seqfu_binary, ['count', str(dataset.path)])
        # Count output is tab-separated: filename, count, type
        count = int(result.stdout.strip().split('\t')[1])
        assert count == 1000, f"Expected 1000 sequences in numbers.fa, got {count}"

    def test_cat_skip(self, seqfu_binary, dataset_manager):
        """Test cat with --skip 2 option"""
        dataset = dataset_manager.get_dataset('numbers')
        assert dataset.path.exists(), f"Test data not found: {dataset.path}"
        result = self.run_command(seqfu_binary, ['cat', '--skip', '2', str(dataset.path)])
        count = self.count_sequences(result.stdout)
        assert count == 500, f"Expected 500 sequences with --skip 2, got {count}"

    def test_cat_skip_first_and_skip(self, seqfu_binary, dataset_manager):
        """Test cat with both --skip-first and --skip options"""
        dataset = dataset_manager.get_dataset('numbers')
        assert dataset.path.exists(), f"Test data not found: {dataset.path}"
        result = self.run_command(
            seqfu_binary, 
            ['cat', '--skip-first', '500', '--skip', '2', str(dataset.path)]
        )
        count = self.count_sequences(result.stdout)
        assert count == 250, f"Expected 250 sequences with --skip 2 and --skip-first 500, got {count}"

    def test_cat_max_bp(self, seqfu_binary, dataset_manager):
        """Test cat with --max-bp option"""
        dataset = dataset_manager.get_dataset('numbers')
        assert dataset.path.exists(), f"Test data not found: {dataset.path}"
        # First get the cat output
        result = self.run_command(
            seqfu_binary,
            ['cat', '--skip-first', '500', '--max-bp', '200', '--skip', '2', str(dataset.path)]
        )
        
        # Write output to a temporary file
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w') as temp:
            temp.write(result.stdout)
            temp.flush()
            # Now run stats on the temporary file
            stats = self.run_command(seqfu_binary, ['stats', temp.name])
            bp_count = self._get_bp_count(stats.stdout)
            assert bp_count <= 200, f"Expected <= 200 bp with --max-bp 200, got {bp_count}"

    def test_cat_jump_to(self, seqfu_binary, dataset_manager):
        """Test cat with --jump-to option"""
        dataset = dataset_manager.get_dataset('numbers')
        assert dataset.path.exists(), f"Test data not found: {dataset.path}"
        result = self.run_command(
            seqfu_binary,
            ['cat', '--jump-to', '500', str(dataset.path)]
        )
        count = self.count_sequences(result.stdout)
        assert count <= 500, f"Expected <= 500 sequences with --jump-to 500, got {count}"

    def _get_bp_count(self, stats_output: str) -> int:
        """Extract total base pairs from tab-separated stats output"""
        lines = stats_output.strip().splitlines()
        if len(lines) != 2:
            raise ValueError(f"Expected header and one data line, got {len(lines)} lines")
            
        # Second line contains the stats
        data = lines[1].split('\t')
        try:
            # Total bp is the third column (index 2)
            return int(data[2])
        except (IndexError, ValueError):
            raise ValueError(f"Could not parse bp count from line: {lines[1]}")