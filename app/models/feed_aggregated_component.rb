class FeedAggregatedComponent < ActiveRecord::Base
  belongs_to :feed
  belongs_to :reference, :polymorphic => true
  belongs_to :secondary_reference, :polymorphic => true

  def self.created_today(feed, reference, secondary_reference = nil)
    time_scope('created', Date.today, feed, reference, secondary_reference)
  end
  
  def self.created_recently(feed, reference, secondary_reference = nil)
    time_scope('created', Time.now - 5.minutes, feed, reference, secondary_reference)
  end

  def self.updated_today(feed, reference, secondary_reference = nil)
    time_scope('updated', Date.today, feed, reference, secondary_reference)
  end
  
  def self.time_scope(action, time, feed, reference, secondary_reference)
    scope = where(:action => action, :feed_id => feed.id, :reference_type => reference.class.to_s, :reference_id => reference.id)
    scope = scope.where("created_at > ?", time)
    
    if secondary_reference.present?
      scope = scope.where(:secondary_reference_type => secondary_reference.class.to_s, :secondary_reference_id => secondary_reference.id)
    end
    
    return scope.first
  end
end