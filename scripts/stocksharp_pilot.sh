#!/usr/bin/env bash
# StockSharp pilot: build and run a headless SMA-crossover backtest using
# StockSharp's free NuGet packages and the project's free sample history data.
# Writes results/stocksharp_result.md in every outcome (success or blocker).
# The full console output of this script is captured by the workflow into
# results/run.log (see the COMMANDS repo variable).

cd "$(dirname "$0")/.."
mkdir -p results
RESULT="results/stocksharp_result.md"
PROJ="src/StockSharpPilot/StockSharpPilot.csproj"
DLL="src/StockSharpPilot/bin/Release/net8.0/StockSharpPilot.dll"

{
  echo "# StockSharp pilot result"
  echo
  echo "- Route taken: alternative route — minimal console project on the free StockSharp NuGet packages (see README.md for why the samples-repo route is not used directly)."
  echo "- Project: \`src/StockSharpPilot\` (Program.cs + SmaStrategy.cs, the SMA strategy from StockSharp's own history-testing sample)."
  echo "- Engine: \`HistoryEmulationConnector\` (StockSharp.Algo.Testing) over the free \`StockSharp.Samples.HistoryData\` package, located at runtime via \`StockSharp.Configuration.Paths\` (the same mechanism the project's samples use)."
  echo "- Packages pinned: StockSharp.Algo 5.0.220, StockSharp.BusinessEntities 5.0.208, StockSharp.Messages 5.0.214, StockSharp.Configuration 5.0.210, StockSharp.Samples.HistoryData 5.0.0 — the last wave targeting net6.0 (2025-07-04), restorable by the mandated .NET 8 SDK. Current StockSharp packages (5.0.230+) target net10.0 only."
  echo
} > "$RESULT"

echo "== dotnet version =="
dotnet --version

echo "== dotnet build =="
dotnet build "$PROJ" -c Release 2>&1 | tee results/build_output.txt
BUILD_RC=${PIPESTATUS[0]}
echo "build exit code: $BUILD_RC"

if [ "$BUILD_RC" -ne 0 ]; then
  {
    echo "## Build result: FAILED (exit code $BUILD_RC)"
    echo
    echo "Exact error lines from the build:"
    echo
    echo '```'
    grep -E "error|Error" results/build_output.txt | head -n 50
    echo '```'
  } >> "$RESULT"
  echo "PILOT RESULT: build failed, see results/stocksharp_result.md"
  exit "$BUILD_RC"
fi

{
  echo "## Build result: succeeded"
  echo
} >> "$RESULT"

echo "== run backtest =="
timeout 1200 dotnet "$DLL" > results/backtest_output.txt 2>&1
RUN_RC=$?
echo "run exit code: $RUN_RC"
cat results/backtest_output.txt
[ -f backtest.log ] && cp backtest.log results/backtest.log

{
  if grep -q "=== Backtest completed ===" results/backtest_output.txt; then
    echo "## Run result: backtest completed (exit code $RUN_RC)"
    echo
    grep -E "^History data path:|^Security:|^Period:" results/backtest_output.txt || true
    echo
    echo "Headline figures (verbatim from the program output):"
    echo
    echo '```'
    sed -n '/=== Backtest completed ===/,$p' results/backtest_output.txt
    echo '```'
  else
    echo "## Run result: FAILED — backtest did not complete (exit code $RUN_RC)"
    echo
    echo "Last lines of the program output:"
    echo
    echo '```'
    tail -n 60 results/backtest_output.txt
    echo '```'
  fi
} >> "$RESULT"

echo "PILOT RESULT written to $RESULT"
exit "$RUN_RC"
