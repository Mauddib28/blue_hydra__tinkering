#!/bin/bash
# Run all Blue Hydra benchmarks

echo "================================="
echo "Blue Hydra Performance Benchmarks"
echo "================================="
echo ""
echo "This will run all performance benchmarks."
echo "Total estimated time: 5-10 minutes"
echo ""

# Create benchmarks directory if it doesn't exist
mkdir -p benchmarks

# Check Ruby version
echo "Ruby version: $(ruby --version)"
echo ""

# Run full benchmark suite
echo "1. Running comprehensive benchmark..."
ruby scripts/run_benchmarks.rb -n "comprehensive" -d 1000 -t 30
echo ""

# Run discovery benchmark
echo "2. Running discovery benchmark..."
ruby scripts/benchmark_discovery.rb
echo ""

# Run database benchmark
echo "3. Running database benchmark..."
ruby scripts/benchmark_database.rb 1000
echo ""

# Run resource benchmark
echo "4. Running resource benchmark..."
ruby scripts/benchmark_resources.rb
echo ""

# Generate summary
echo "5. Generating summary report..."
echo ""
echo "Benchmark Results Summary"
echo "========================"
echo ""
echo "Benchmark files created in: benchmarks/"
ls -la benchmarks/*.json 2>/dev/null | tail -5
echo ""
echo "CSV files for graphing:"
ls -la benchmarks/*.csv 2>/dev/null | tail -5
echo ""

# Create combined report
cat > benchmarks/BENCHMARK_SUMMARY.md << EOF
# Blue Hydra Benchmark Summary

Generated: $(date)

## Benchmark Files

$(ls -1 benchmarks/*.json | tail -10)

## Quick Results

To view detailed results:
- JSON files contain raw benchmark data
- CSV files can be imported into spreadsheet apps
- Compare legacy vs modern using the compare feature

## Next Steps

1. Review individual benchmark files
2. Compare with legacy version results
3. See docs/performance-comparison-report.md for analysis

EOF

echo "Summary saved to: benchmarks/BENCHMARK_SUMMARY.md"
echo ""
echo "All benchmarks complete!"
echo ""
echo "To compare with legacy results:"
echo "  ruby scripts/run_benchmarks.rb -c benchmarks/<legacy_file>.json" 