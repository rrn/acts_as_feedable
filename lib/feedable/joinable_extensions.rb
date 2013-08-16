module Joinable::ActsAsJoinable::ClassMethods
  class << self
    alias_method :extended_without_feedable, :extended

    def extended(base)
      extended_without_feedable(base)
      base.before_validation :dont_create_membership_invitation_feeds, :on => :create
    end
  end
end

module Joinable::ActsAsJoinable::InstanceMethods
  # Don't create feeds for membership invitations when the joinable itself is being created
  def dont_create_membership_invitation_feeds
    membership_invitations.each { |invitation| invitation.no_default_feed = true }
  end
end

module JoinableExtensions
  def self.add
    extend_membership
    extend_membership_invitation
    extend_membership_request
  end

  def self.extend_membership
    Membership.class_eval do
      before_destroy :ensure_feed_creation

      acts_as_feedable :parent => 'joinable', :delegate => {:references => 'user', :actions => {:created => 'joined', :destroyed => 'left'}}

      private

      def ensure_feed_creation
        with_feed(initiator) if initiator.present?
      end
    end
  end

  def self.extend_membership_invitation
    MembershipInvitation.class_eval do
      before_create :ensure_feed_creation
      before_destroy :ensure_feed_creation

      acts_as_feedable :parent => 'joinable', :delegate => {:references => 'user', :actions => {:created => 'invited', :destroyed => 'cancelled_invite'}}

      attr_accessor :no_default_feed

      private

      def create_associated_membership_on_accept(current_user)
        self.no_default_feed = true # Default feed has incorrect initiator. We're about to create a feed with the correct initiator.
        Membership.create_with_feed(user, :joinable => joinable, :user => user, :permissions => permissions)
      end
      
      def destroy_self_on_decline(current_user)
        self.no_default_feed = true # Default feed has incorrect initiator. We're about to create a feed with the correct initiator.
        destroy_with_feed(user)
      end

      # Don't create a destroyed feed if the user is accepting a membership invitation or a membership request exists for this User.
      # In that case, a membership was created, and this invitation should be 'invisible' to the Users and the UI. Thus no feeds should be created.
      def ensure_feed_creation
        with_feed(initiator) unless no_default_feed || joinable.membership_for?(user) || joinable.membership_request_for?(user)
      end
    end
  end

  def self.extend_membership_request
    MembershipRequest.class_eval do
      acts_as_feedable :parent => 'joinable', :delegate => {:references => 'user', :actions => {:created => 'requested', :destroyed => 'cancelled_request'}}
      
      private

      def create_associated_membership_on_grant(current_user, permissions)
        Membership.create_with_feed(current_user, :joinable => joinable, :user => user, :permissions => permissions)
      end
    end
  end
end