module DelayedPaperclip
  class Railtie < ::Rails::Railtie
    initializer 'delayed_paperclip.insert_into_active_record' do
      ActiveSupport.on_load :active_record do
        DelayedPaperclip::Railtie.insert
      end
    end

    def self.insert
      ActiveRecord::Base.extend DelayedPaperclip::ClassMethods
      Paperclip::Attachment.prepend DelayedPaperclip::Attachment
    end
  end
end
