import pytest
import tempfile
from pathlib import Path
from test_seqfu import (
    SeqFuTestBase,
    seqfu_binary,
    dataset_manager,
    Dataset
)

class TestStats(SeqFuTestBase):
    """Tests for the stats command"""

    def test_basic_stats_output(self, seqfu_binary, dataset_manager):
        """Test basic stats output format and values"""
        dataset = dataset_manager.get_dataset('amplicon')
        result = self.run_command(seqfu_binary, ['stats', '--basename', str(dataset.path)])
        
        lines = result.stdout.strip().splitlines()
        assert len(lines) == 2, f"Expected 2 lines of output, got {len(lines)}"
        
        # Parse stats from tab-separated output
        stats = lines[1].split('\t')
        assert int(stats[1]) == 78730, f"Expected 78730 sequences, got {stats[1]}"
        assert int(stats[2]) == 24299931, f"Expected 24299931 total bases, got {stats[2]}"
        assert int(stats[4]) == 316, f"Expected N50 of 316, got {stats[4]}"

    def test_csv_output(self, seqfu_binary, dataset_manager):
        """Test CSV output format"""
        dataset = dataset_manager.get_dataset('amplicon')
        result = self.run_command(
            seqfu_binary, 
            ['stats', '--basename', '--csv', str(dataset.path)]
        )
        
        n50 = int(result.stdout.strip().splitlines()[1].split(',')[4])
        assert n50 == 316, f"Expected N50 of 316 in CSV output, got {n50}"

    def test_nice_output(self, seqfu_binary, dataset_manager):
        """Test nice output format"""
        dataset = dataset_manager.get_dataset('amplicon')
        result = self.run_command(
            seqfu_binary, 
            ['stats', '--basename', '--nice', str(dataset.path)]
        )
        
        lines = [line for line in result.stdout.splitlines() if line.strip()]
        assert len(lines) == 5, f"Expected 5 lines in nice output, got {len(lines)}"

    def test_json_and_multiqc_output(self, seqfu_binary, dataset_manager, tmp_path):
        """Test JSON and MultiQC output"""
        dataset = dataset_manager.get_dataset('amplicon')
        multiqc_file = tmp_path / "multiqc_stats.txt"
        
        result = self.run_command(
            seqfu_binary, 
            ['stats', '--basename', '--json', '--multiqc', str(multiqc_file), str(dataset.path)]
        )
        
        assert len(result.stdout.strip().splitlines()) == 1, "JSON output should be one line"
        multiqc_lines = [line for line in multiqc_file.read_text().splitlines() if line.strip()]
        assert len(multiqc_lines) == 39, \
            f"Expected 39 lines in MultiQC output, got {len(multiqc_lines)}"

    def test_multiple_files_default_sort(self, seqfu_binary, dataset_manager):
        """Test stats on multiple files with default sorting"""
        paths = [
            str(dataset_manager.get_dataset(d).path) 
            for d in ['amplicon', 'sort', 'mini']
            if dataset_manager.get_dataset(d).path.exists()
        ]
        
        # Debug output
        print("\nPaths being tested:", paths)
        
        result = self.run_command(seqfu_binary, ['stats', '--basename'] + paths)
        print("\nCommand output:", result.stdout)
        
        lines = result.stdout.strip().splitlines()
        assert len(lines) > 1, "Expected at least header and one data line"
        first_file = lines[1].split('\t')[0]
        assert "filt" in first_file, f"Expected 'filt' in first filename, got {first_file}"

    def test_multiple_files_n50_sort(self, seqfu_binary, dataset_manager):
        """Test stats on multiple files sorted by N50"""
        paths = [
            str(dataset_manager.get_dataset(d).path) 
            for d in ['amplicon', 'sort', 'mini']
            if dataset_manager.get_dataset(d).path.exists()
        ]
        
        # Debug output
        print("\nPaths to test:", paths)
        
        # Run stats with N50 sorting
        result = self.run_command(
            seqfu_binary, 
            ['stats', '--basename', '--sort', 'n50', '--reverse'] + paths
        )
        
        print("\nCommand output:", result.stdout)
        lines = result.stdout.strip().splitlines()
        assert len(lines) > 1, "Expected at least header and one data line"
        
        # Get N50 values
        n50_values = []
        for line in lines[1:]:  # Skip header
            cols = line.split('\t')
            n50_values.append((cols[0], int(cols[4])))
        
        # Verify descending order
        for i in range(len(n50_values) - 1):
            assert n50_values[i][1] >= n50_values[i + 1][1], \
                f"N50 values not in descending order: {n50_values}"

    def test_gc_content(self, seqfu_binary, dataset_manager, tmp_path):
        """Test GC content calculation"""
        test_cases = [
            ('gc_full', 1.00),
            ('gc_zero', 0.00),
            ('gc_half', 0.50)
        ]
        
        for dataset_name, expected_gc in test_cases:
            dataset = dataset_manager.get_dataset(dataset_name)
            if not dataset.path.exists():
                pytest.skip(f"Test file {dataset.path} not found")
                
            result = self.run_command(seqfu_binary, ['stats', '--gc', str(dataset.path)])
            lines = result.stdout.strip().splitlines()
            print(f"\nGC test output for {dataset_name}:", result.stdout)
            
            assert len(lines) > 1, f"Expected at least 2 lines of output for {dataset_name}"
            gc_content = float(lines[1].split('\t')[10])
            assert abs(gc_content - expected_gc) < 0.01, \
                f"For {dataset_name}, expected GC content {expected_gc}, got {gc_content}"

    def test_sort_by_total_sequences(self, seqfu_binary, dataset_manager):
        """Test sorting by total sequences"""
        file_datasets = ['prot', 'prot2', 'test', 'test_fasta',
                        'test_fastq', 'test2_fastq', 'test4']
        
        paths = [
            str(dataset_manager.get_dataset(d).path) 
            for d in file_datasets
            if dataset_manager.get_dataset(d).path.exists()
        ]
        
        if not paths:
            pytest.skip("No test files found")
        
        # Debug output
        print("\nPaths to test:", paths)
        
        # Test forward sort
        result = self.run_command(
            seqfu_binary, 
            ['stats', '-a', '--sort', 'tot', '--reverse'] + paths
        )
        
        print("\nForward sort output:", result.stdout)
        lines = result.stdout.strip().splitlines()
        assert len(lines) > 1, "Expected at least header and one data line"
        
        # Get sequence counts
        seq_counts = []
        for line in lines[1:]:  # Skip header
            cols = line.split('\t')
            seq_counts.append(int(cols[2]))
            
        # Verify ascending order
        assert seq_counts == sorted(seq_counts), \
            f"Sequence counts not in ascending order: {seq_counts}"
        
        # Test reverse sort
        result = self.run_command(
            seqfu_binary, 
            ['stats', '-a', '--sort', 'tot', '--reverse'] + paths
        )
        
        print("\nReverse sort output:", result.stdout)
        lines = result.stdout.strip().splitlines()
        assert len(lines) > 1, "Expected at least header and one data line"
        
        # Get sequence counts
        seq_counts = []
        for line in lines[1:]:  # Skip header
            cols = line.split('\t')
            seq_counts.append(int(cols[2]))
            
        # Verify descending order
        assert seq_counts == sorted(seq_counts, reverse=False), \
            f"Sequence counts not in descending order: {seq_counts}"