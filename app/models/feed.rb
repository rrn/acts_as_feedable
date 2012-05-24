class Feed < ActiveRecord::Base
  belongs_to :initiator, :class_name => 'User'
  
  belongs_to :feedable, :polymorphic => true
  belongs_to :scoping_object, :polymorphic => true
  
  has_many :feed_aggregated_components, :dependent => :destroy, :order => 'feed_aggregated_components.updated_at DESC'
  
  # When the feedable has been deleted, inherit permissions from the scoping_object instead
  acts_as_joinable_component :parent => 'permission_inheritance_target', :polymorphic => true
  
  default_scope order('feeds.updated_at DESC')

  # Filter feeds about public joinables that you haven't joined
  scope :without_unjoined, lambda {|joinable_type, user| 
    where("feeds.scoping_object_type IS NULL OR 
           feeds.scoping_object_type != '#{joinable_type}' OR 
           EXISTS (SELECT * FROM memberships WHERE memberships.joinable_type = '#{joinable_type}' AND memberships.joinable_id = feeds.scoping_object_id AND memberships.user_id = ?)", user.id)
  }
  
  # The feed may have been delegated so inherit permissions from scoping_object
  # eg. a user (non-permissible) leaves a project, the permission to view the feed rests with the project because the feedable is the user itself
  def permission_inheritance_target_type
    if feedable.acts_like?(:permissable)
      feedable_type
    else
      scoping_object_type
    end
  end
  
  def permission_inheritance_target_id
    if feedable.acts_like?(:permissable)
      feedable_id
    else
      scoping_object_id
    end
  end

  # Used to group feeds by the day they occurred
  def date
    updated_at.to_date.to_formatted_s(:long_ordinal)
  end

  # Is this an aggregate feed
  def aggregate?
    added_count > 0 || updated_count > 0 || removed_count > 0
  end
end