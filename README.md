# stocksharp-runner

Run [StockSharp](https://github.com/StockSharp/StockSharp) — the .NET algorithmic
trading platform — in GitHub Actions, following the moos-labs runner pattern:
`workflow_dispatch` only, the commands live in the `COMMANDS` Actions variable,
and everything the run produces lands in a `results` artifact.

## How it runs

- Workflow: `.github/workflows/run.yml` (manual dispatch only)
  - `actions/setup-dotnet@v4` with `dotnet-version: '8.x'`
  - a `Run commands` step whose run line is exactly `run: ${{ vars.COMMANDS }}`
  - a final `actions/upload-artifact@v4` step (`name: results`, `path: results/`, `if: always()`)
- Repo Actions variable `COMMANDS`:
  ```
  mkdir -p results
  set -o pipefail; bash scripts/stocksharp_pilot.sh 2>&1 | tee results/run.log
  ```
- `scripts/stocksharp_pilot.sh` builds `src/StockSharpPilot`, runs the backtest,
  and always writes `results/stocksharp_result.md` (success figures verbatim, or
  the exact build/run blocker). Full console output: `results/run.log`;
  raw program output: `results/backtest_output.txt`.

## The pilot

A headless SMA-crossover backtest (long SMA 80 / short SMA 10, 1-minute candles,
volume 1, 0.01-per-trade commission rule — the parameters of StockSharp's own
history-testing sample), driven through `HistoryEmulationConnector` over the
free `StockSharp.Samples.HistoryData` package. With the pinned packages that is
`SBER@TQBR`, 2020-04-01 → 2020-04-30, located at runtime via
`StockSharp.Configuration.Paths` — the same mechanism the project's samples use.
`src/StockSharpPilot/SmaStrategy.cs` is the strategy from the project's sample
(`Samples/07_Testing/01_History/SmaStrategy.cs`); see the header comment in that
file for the one signature adaptation the published packages require.

## Honest notes — why this route, and what is pinned

- The samples no longer live in a separate `StockSharp/Samples` repo (that repo
  name returns 404); they are under `Samples/` in `StockSharp/StockSharp`.
  The history-testing sample there is a WPF Windows app — not headless-runnable
  on a Linux runner. The project later added a console variant
  (`Samples/07_Testing/04_HistoryConsole`), but current `master` targets
  **.NET 10**, and current StockSharp NuGet packages (5.0.230+) ship
  `lib/net10.0` only — neither can be built by this runner pattern's mandated
  .NET 8 SDK.
- So this runner takes the documented alternative route: a minimal console
  project referencing the free StockSharp NuGet packages, with code modelled
  directly on the project's own History/HistoryConsole samples. The packages
  are pinned to the last wave that a .NET 8 SDK can restore — the 2025-07-04
  wave targeting `net6.0`: `StockSharp.Algo` 5.0.220,
  `StockSharp.BusinessEntities` 5.0.208, `StockSharp.Messages` 5.0.214,
  `StockSharp.Configuration` 5.0.210, `StockSharp.Samples.HistoryData` 5.0.0.
  The app itself targets `net8.0` (net8 apps can consume the net6 libraries).
- Licensing: StockSharp's core is free and these packages restore from
  nuget.org with no license key (`requireLicenseAcceptance` is false). Some
  StockSharp exchange connectors are commercial products; none are used here —
  only the free core, the free emulation engine and the free sample data.
- The sample program's interactive report-format prompt (JSON/XML/CSV/Excel)
  at the end of the original console sample is omitted — this runner is
  headless, and the statistics are printed to the console instead.

## Changing the run

Edit the `COMMANDS` Actions variable, or replace `scripts/stocksharp_pilot.sh`
with your own build/run logic. Keep line 1 as `mkdir -p results` and start
line 2 with `set -o pipefail;` so failures surface in the workflow log.
