require 'stringio'
require 'test_helper'
require 'base_delayed_paperclip_test'

def silent_warnings
  old_stderr = $stderr
  $stderr = StringIO.new
  yield
ensure
  $stderr = old_stderr
end

# delayed_job itself is pretty noisy at the moment, ignore these
silent_warnings do
  require 'delayed_job'
end

Delayed::Worker.backend = :active_record if Delayed::Worker.respond_to?(:backend=)

class DelayedPaperclipTest < DelayedPaperclip::TestCase
  include BaseDelayedPaperclipTest

  def setup
    super
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::DelayedJob
    build_delayed_jobs
  end

  def process_jobs
    Delayed::Worker.new.work_off
  end

  def jobs_count
    Delayed::Job.count
  end

  def test_perform_job
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.image = File.open("#{RAILS_ROOT}/test/fixtures/12k.png")
    Paperclip::Attachment.any_instance.expects(:reprocess!)
    dummy.save!
    Delayed::Job.last.payload_object.perform
  end

  def build_delayed_jobs
    ActiveRecord::Base.connection.create_table :delayed_jobs, :force => true do |table|
      table.integer  :priority, :default => 0      # Allows some jobs to jump to the front of the queue
      table.integer  :attempts, :default => 0      # Provides for retries, but still fail eventually.
      table.text     :handler                      # YAML-encoded string of the object that will do work
      table.string   :last_error                   # reason for last failure (See Note below)
      table.datetime :run_at                       # When to run. Could be Time.now for immediately, or sometime in the future.
      table.datetime :locked_at                    # Set when a client is working on this object
      table.datetime :failed_at                    # Set when all retries have failed (actually, by default, the record is deleted instead)
      table.string   :locked_by                    # Who is working on this object (if locked)
      table.string   :queue
      table.timestamps
    end
  end

end
