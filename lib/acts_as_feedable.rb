require 'feedable/acts_as_feedable'

module ActsAsFeedable
  class Engine < Rails::Engine
    initializer "acts_as_feedable.init" do
      ActiveRecord::Base.send :extend, Feedable::ActsAsFeedable::ActMethod

      # Add feeds to joinable models
      Membership.acts_as_feedable :parent => 'joinable', :delegate => {:references => 'user', :actions => {:created => 'joined', :destroyed => 'left'}}
      MembershipInvitation.acts_as_feedable :parent => 'joinable', :delegate => {:references => 'user', :actions => {:created => 'invited', :destroyed => 'cancelled_invite'}}
      MembershipRequest.acts_as_feedable :parent => 'joinable', :delegate => {:references => 'user', :actions => {:created => 'requested', :destroyed => 'cancelled_request'}}
    end    
  end
end