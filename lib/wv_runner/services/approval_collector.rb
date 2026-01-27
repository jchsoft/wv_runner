# frozen_string_literal: true

module WvRunner
  # Collects Bash commands that require user approval during Claude Code execution.
  # These commands can be added to Claude Code's allowed prompts for future runs.
  class ApprovalCollector
    @@collected_commands = []

    class << self
      def add(command)
        return if command.nil? || command.strip.empty?

        # Avoid duplicates
        @@collected_commands << command unless @@collected_commands.include?(command)
      end

      def commands
        @@collected_commands.dup
      end

      def clear
        @@collected_commands = []
      end

      def any?
        @@collected_commands.any?
      end

      # Extracts command from Claude's approval error message
      # Example: "This Bash command contains multiple operations. The following parts require approval: if [ -f \"bin/ci\" ], then bin/ci, else echo \"...\", fi"
      def extract_from_error(error_message)
        return if error_message.nil?
        return unless error_message.include?('require approval') || error_message.include?('requires approval')

        # Pattern 1: "The following parts require approval: <command>"
        match = error_message.match(/The following parts require approval:\s*(.+)/i)
        if match
          add(match[1].strip)
          return
        end

        # Pattern 2: "requires approval: <command>"
        match = error_message.match(/requires approval:\s*(.+)/i)
        add(match[1].strip) if match
      end

      def print_summary
        return unless any?

        Logger.info_stdout ''
        Logger.info_stdout '=' * 80
        Logger.info_stdout 'COMMANDS THAT REQUIRED APPROVAL DURING THIS SESSION:'
        Logger.info_stdout '=' * 80
        Logger.info_stdout ''
        Logger.info_stdout 'Add these to your Claude Code settings to auto-approve in future runs:'
        Logger.info_stdout ''

        commands.each_with_index do |cmd, idx|
          Logger.info_stdout "  #{idx + 1}. #{cmd}"
        end

        Logger.info_stdout ''
        Logger.info_stdout 'To add these to ~/.claude/settings.json, add entries like:'
        Logger.info_stdout '  {"tool": "Bash", "prompt": "<command description>"}'
        Logger.info_stdout ''
        Logger.info_stdout '=' * 80
      end
    end
  end
end
