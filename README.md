# WvRunner

A gem that adds rake tasks to Rails applications for automated Claude Code execution of WorkVector tasks.

## Installation

Add to your Gemfile:
```ruby
gem 'wv_runner', git: 'https://github.com/jchsoft/wv_runner.git'
```

Then run:
```bash
bundle install
```

## Usage

### Available Rake Tasks

#### Run a single task once
```bash
rake wv_runner:run_once
```

#### Run tasks until end of today
```bash
rake wv_runner:run_today
```

#### Run tasks continuously in a daily loop
```bash
rake wv_runner:run_daily
```

### Environment Variables

| Variable | Values | Description |
|----------|--------|-------------|
| `verbose` | `true` | Show full JSON output instead of formatted messages |
| `WV_RUNNER_ASCII` | `1` | Use ASCII icons instead of emoji (for terminals without emoji support) |

Example:
```bash
WV_RUNNER_ASCII=1 rake wv_runner:run_once
```

## Architecture

### Core Components

- **WorkLoop**: Main execution loop that orchestrates task processing
- **ClaudeCode**: Interface to Claude Code runner
- **Decider**: Decision logic for task routing and prioritization

## Testing

Run all tests using the test runner:
```bash
ruby test_runner.rb
```

This will run all 128 tests across 14 test files and provide a summary:
- Total runs, assertions, failures, and errors
- Individual test file results
- Clear pass/fail status

You can also run individual test files:
```bash
ruby -I lib -I test test/services/work_loop_test.rb
ruby -I lib -I test test/services/claude_code_base_test.rb
ruby -I lib -I test test/services/claude_code_step_tests.rb
```

## Development

This gem is under active development. The service classes are currently scaffolded and ready for implementation.

## License

MIT
