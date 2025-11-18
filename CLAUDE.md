
## LLM Memory Notes MCP Usage
- Memory identifier for this project: `wv-runner` (contains architecture, patterns, commands, testing info)

## WorkVector
- Project name is: WorkVector
- project_relative_id=7

## Testing
- Test runner: `ruby test_runner.rb` runs all 128 tests across 14 test files
- Individual tests: `ruby -I lib -I test test/services/<test_file>.rb`
- All tests must pass before committing changes

## Version Management
**Important**: After successfully completing this wv_runner task (when code is committed and ready):
- Run: `ruby bin/increment_version.rb` to increment the wv_runner version by 0.1
- This ONLY increments the wv_runner version itself, not projects where runner is used
- Version file: `lib/wv_runner/version.rb`
- Current version is displayed at startup with every run
- Versions follow pattern: 0.1.0 → 0.1.1 → 0.1.2 → ... → 0.1.9 → 0.2.0 → 0.2.1 → etc
- Run this command AFTER you've committed your code changes
- Example: After implementing a feature, commit your code, then run `ruby bin/increment_version.rb` before ending the task