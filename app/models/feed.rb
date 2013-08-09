class Feed < ActiveRecord::Base
  belongs_to :initiator, :class_name => 'User'
  
  belongs_to :feedable, :polymorphic => true
  belongs_to :scoping_object, :polymorphic => true
  
  has_many :feed_aggregated_components, lambda { order 'feed_aggregated_components.updated_at DESC' }, :dependent => :destroy
  
  default_scope lambda { order('feeds.updated_at DESC') }

  # Used to group feeds by the day they occurred
  def date
    updated_at.to_date.to_formatted_s(:long_ordinal)
  end

  # Is this an aggregate feed
  def aggregate?
    added_count > 0 || updated_count > 0 || removed_count > 0
  end
end