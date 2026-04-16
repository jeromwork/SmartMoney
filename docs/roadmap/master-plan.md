# SmartMoney Master Plan

## Current Status

- Step P0 (Architecture decision): done
- Step P1 (Orchestrator + provider contracts + adapters): done
- Next in queue: P2 (extended signal packs and compatibility tests)

## Plugin Architecture Rules

1. `SmartMoneyEA` is an orchestrator only: no pattern detection in EA code.
2. Pattern logic must live in indicator providers or engine providers behind the same interfaces.
3. Every provider must implement stable contracts from `SmartMoneyContracts.mqh`.
4. Strategy swap must be done through profile/config (`ProvidersProfile`, composition mode, filters), not EA rewrites.
5. Signal aggregation must go through `SignalComposer` with configurable composition rules.
6. Live and AutoTest modes must reuse the same pipeline; only confirmation/execution policy may differ.
7. Provider failures must degrade gracefully (skip provider, keep EA running, log diagnostics).

## Mandatory Contracts

- `IIndicatorProvider`: `Init`, `Refresh`, `GetValue`, `GetState`, `Name`, `Deinit`
- `ISignalProvider`: `BuildSignal`, `Name`, `Deinit`
- `IFilterProvider`: `Allow`, `Name`
- `IExecutionPolicy`: `BuildOrder`, `CanSend`, `Send`, `Name`

## Roadmap

1. P0: lock plugin architecture and DTOs.
2. P1: implement orchestrator MVP with registry, adapters, composer, spread filter, execution policy.
3. P2: add profile matrix (`strict`, `normal`, `relaxed`) and contract tests for swap compatibility.
4. P3: add additional indicator packs and multi-hypothesis providers.
5. P4: add performance profile for AutoTest and failure isolation tests.
6. P5: add DOM layer in Wave 2 as optional provider pack.

## Done in P1

- Added provider contracts and DTOs (`SignalContext`, `SignalFeature`).
- Added two adapter sources:
  - `iCustom` indicator provider (`SmartMoneyZones`)
  - class-engine fallback provider
- Added `ProviderRegistry` and profile-based provider loading.
- Added `SignalComposer` with `AND/OR/ScoreThreshold` composition.
- Added runtime modes in one EA:
  - `LiveManualConfirm`
  - `AutoTest`
- Added multi-symbol and multi-timeframe scanner matrix from CSV inputs.

## Definition of Done for Next Step (P2)

- Swap provider A/B without EA changes.
- Backward-compatible profiles remain runnable.
- Contract tests cover init/refresh/getvalue/deinit for every provider.
- Composition mode switch changes behavior by config only.
