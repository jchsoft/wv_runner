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

## Architecture

### Core Components

- **WorkLoop**: Main execution loop that orchestrates task processing
- **ClaudeCode**: Interface to Claude Code runner
- **Decider**: Decision logic for task routing and prioritization

## Testing

Run all tests:
```bash
ruby -I lib -I test test/services/work_loop_test.rb test/services/claude_code_test.rb test/services/decider_test.rb
```

## Development

This gem is under active development. The service classes are currently scaffolded and ready for implementation.

## License

MIT
