
## LLM Memory Notes MCP Usage
- Memory identifier for this project: `wv-runner` (contains architecture, patterns, commands, testing info)

## WorkVector
- Project name is: WorkVector
- project_relative_id=7

## Version Management
**Important**: After successfully completing this wv_runner task (when code is committed and ready):
- Run: `bin/rails wv_runner:increment_version` to increment the wv_runner version by 0.1
- This ONLY increments the wv_runner version itself, not projects where runner is used
- Version file: `lib/wv_runner/version.rb`
- Current version is displayed at startup with every run
- Versions follow pattern: 0.1.0 → 0.1.1 → 0.1.2 → ... → 0.1.9 → 0.2.0 → 0.2.1 → etc
- Run this command AFTER you've committed your code changes
- Example: After implementing a feature, commit your code, then run `bin/rails wv_runner:increment_version` before ending the task