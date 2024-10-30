module DelayedPaperclip
  module Attachment
    attr_accessor :job_is_processing

    def post_processing
      !delay_processing?
    end

    def post_processing=(value)
      @post_processing_with_delay = value
    end

    def delayed_options
      instance.class.attachment_definitions[name][:delayed]
    end

    def delay_processing?
      if !defined?(@post_processing_with_delay) || @post_processing_with_delay.nil?
        !!delayed_options
      else
        !@post_processing_with_delay
      end
    end

    def processing?
      instance.send(:"#{name}_processing?")
    end

    def process_delayed!
      self.job_is_processing = true
      reprocess!
      self.job_is_processing = false
    end

    def post_process_styles(*)
      super

      # update_column is available in rails 3.1 instead we can do this to update the attribute without callbacks

      params_to_update = {}
      #instance.update_column("#{name}_processing", false) if instance.respond_to?(:"#{name}_processing?")
      if instance.respond_to?(:"#{name}_processing?")
        instance.send("#{name}_processing=", false)
        params_to_update["#{name}_processing"] = false
      end
      # Reset the file size and image sizes if the original file was reprocessed.
      if queued_for_write[:original] && instance_read(:file_size) != queued_for_write[:original].size.to_i
        collect_to_update('file_size', queued_for_write[:original].size.to_i, params_to_update)
        sizes = FastImage.size(queued_for_write[:original])
        if sizes && sizes[0] && sizes[1]
          collect_to_update('width', sizes[0], params_to_update)
          collect_to_update('height', sizes[1], params_to_update)
        end
      end
      if params_to_update.any?
        instance.class.where(instance.class.primary_key => instance.id).update_all(params_to_update)
      end
    end

    def collect_to_update(attr, value, params_to_update)
      return unless instance.respond_to?(:"#{name}_#{attr}=")

      instance.send("#{name}_#{attr}=", false)
      params_to_update["#{name}_#{attr}"] = value
    end

    def save
      was_dirty = dirty?
      super.tap do
        instance.prepare_enqueueing_for(name) if delay_processing? && was_dirty
      end
    end

    def most_appropriate_url
      if original_filename.nil? || delayed_default_url?
        default_url
      else
        options.url
      end
    end

    def delayed_default_url?
      !(job_is_processing || dirty? || !delayed_options.try(:[], :url_with_processing) ||
        !(instance.respond_to?(:"#{name}_processing?") && processing?))
    end
  end
end
