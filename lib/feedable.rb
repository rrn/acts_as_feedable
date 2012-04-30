require 'feedable/acts_as_feedable'

ActiveRecord::Base.send(:extend, Feedable::ActsAsFeedable::ActMethod)