# frozen_string_literal: true

module McptaskRunner
  module Concerns
    # Handles OS-level process lifecycle: SIGTERM, SIGKILL, process groups, waiting for exit
    module ProcessManagement
      PROCESS_KILL_TIMEOUT = 5  # seconds to wait for SIGTERM before SIGKILL
      PROCESS_WAIT_TIMEOUT = 15 # seconds to wait for process exit after kill

      private

      def kill_process(pid)
        return unless pid

        pgid = resolve_process_group(pid)
        kill_target = pgid ? -pgid : pid
        target_label = pgid ? "process group #{pgid}" : "pid #{pid}"

        Logger.info_stdout "[#{@log_tag}] Terminating Claude #{target_label}..."
        begin
          Process.kill('TERM', kill_target)
        rescue Errno::ESRCH
          return
        rescue Errno::EPERM
          Logger.warn "[#{@log_tag}] No permission to kill #{target_label}, falling back to pid #{pid}"
          safe_kill('TERM', pid) || return
        end

        PROCESS_KILL_TIMEOUT.times do
          sleep(1)
          begin
            Process.kill(0, pid)
          rescue Errno::ESRCH
            Logger.debug "[#{@log_tag}] Process #{pid} terminated after SIGTERM"
            return
          end
        end

        Logger.warn "[#{@log_tag}] Process #{pid} not responding to SIGTERM, sending SIGKILL..."
        begin
          Process.kill('KILL', kill_target)
        rescue Errno::ESRCH, Errno::EPERM
          safe_kill('KILL', pid)
        end
      rescue StandardError => e
        Logger.warn "[#{@log_tag}] Error during process cleanup: #{e.message}"
      end

      def wait_for_process(wait_thr)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + PROCESS_WAIT_TIMEOUT

        loop do
          return wait_thr.value unless wait_thr.alive?

          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            Logger.warn "[#{@log_tag}] Process still alive after #{PROCESS_WAIT_TIMEOUT}s, force killing..."
            force_kill_process_group(wait_thr.pid)
            return wait_thr.value
          end

          sleep(0.5)
        end
      end

      def force_kill_process_group(pid)
        pgid = resolve_process_group(pid)
        target = pgid ? -pgid : pid

        Process.kill('KILL', target)
      rescue Errno::ESRCH, Errno::EPERM
        safe_kill('KILL', pid)
      end

      def resolve_process_group(pid)
        Process.getpgid(pid)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end

      def safe_kill(signal, pid)
        Process.kill(signal, pid)
        true
      rescue Errno::ESRCH
        false
      end
    end
  end
end
