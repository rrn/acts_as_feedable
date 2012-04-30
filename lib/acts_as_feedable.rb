require 'feedable/acts_as_feedable'

module ActsAsFeedable
  class Engine < Rails::Engine
    initializer "acts_as_feedable.init" do
      ActiveRecord::Base.send :extend, Feedable::ActsAsFeedable::ActMethod
    end    
  end
end