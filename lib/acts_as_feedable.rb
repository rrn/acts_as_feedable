require 'feedable/acts_as_feedable'

module ActsAsFeedable
  class Engine < Rails::Engine
    initializer "acts_as_feedable.init" do
      ActiveRecord::Base.send :extend, Feedable::ActsAsFeedable::ActMethod
    end

    config.to_prepare do
      if defined?(ActsAsJoinable::Engine)
        require 'feedable/joinable_extensions'
        JoinableExtensions.add
      else
        puts "[ActsAsFeedable] ActsAsJoinable not loaded. Skipping extensions."
      end
    end
  end
end