
## Hledání informací

| Typ informace | Nástroj | Příklad |
|---------------|---------|---------|
| **Symboly** (třídy, metody) | CodeGraph (`mcp__codegraph__*`) | "najdi `WorkLoop`" |
| **Moduly, concerns, mixiny** | **LSP** `documentSymbol` nebo `Grep` | `module InstructionBuilding` |
| **Struktura souboru** (všechny symboly) | **LSP** `documentSymbol` | kompletní přehled tříd, modulů, metod |
| **Kdo volá/referencuje symbol** | **LSP** `findReferences` / `incomingCalls` | přesné reference z known pozice |
| **Architektura, patterns, lessons learned** | `/memory-search` skill | "jak funguje triage?" |

**LSP tool je dostupný** (ruby-lsp plugin) — vidí moduly, concerns, vše co CodeGraph nevidí. Vyžaduje file:line pozici, takže nejdřív najdi soubor přes CodeGraph/Grep, pak analyzuj přes LSP.
**CodeGraph omezení pro Ruby:** Neindexuje `module` definice (concerns, namespace modules).

## LLM Memory Notes MCP Usage
- Memory identifier for this project: `wv-runner` (contains architecture, patterns, commands, testing info)
- **Search**: Use `/memory-search` skill (runs on Haiku, returns compact filtered results)
- **Do NOT use direct `ReadMcpResourceTool`** for searching — returns too verbose data into context

## WorkVector
- Project name is: WorkVector
- project_relative_id=7

## CI & Quality Checks
- **Full CI**: `ruby bin/ci` runs all checks (tests, RuboCop, Reek, Flay)
- **Tests only**: `ruby test_runner.rb` runs all tests
- **Individual tests**: `ruby -I lib -I test test/services/<test_file>.rb`
- **All checks must pass before committing changes**

## Version Management
**Important**: After successfully completing this wv_runner task (when code is committed and ready):
- Run: `ruby bin/increment_version.rb` to increment the wv_runner version by 0.1
- This ONLY increments the wv_runner version itself, not projects where runner is used
- Version file: `lib/wv_runner/version.rb`
- Current version is displayed at startup with every run
- Versions follow pattern: 0.1.0 → 0.1.1 → 0.1.2 → ... → 0.1.9 → 0.2.0 → 0.2.1 → etc
- Run this command AFTER you've committed your code changes
- Example: After implementing a feature, commit your code, then run `ruby bin/increment_version.rb` before ending the task