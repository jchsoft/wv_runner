
## LLM Memory Notes MCP Usage
- Memory identifier for this project: `wv-runner` (contains architecture, patterns, commands, testing info)

## WorkVector
- Project name is: WorkVector
- project_relative_id=7

## Version Management
**Important**: After successfully completing any task, the runner automatically increments the version by 0.1 increments:
- Version file: `lib/wv_runner/version.rb`
- Current version is displayed at startup
- Version increments happen in `WvRunner::VersionManager`
- Versions follow pattern: 0.1.0 → 0.1.1 → 0.1.2 → ... → 0.1.9 → 0.2.0
- Each successful task completion (status="success") triggers auto-increment
- Version file is automatically updated and reloaded after each increment