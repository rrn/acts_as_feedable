module Feedable #:nodoc:
  module ActsAsFeedable #:nodoc:
    module ActMethod
      # Configuration options are:
      #
      # * +keep_feeds_when_destroyed+ - specifies whether to keep the feeds when a feedable is destroyed. This should only be done if the feedable is public or is scoped to another feedable.
      # * +target_name+ - specifies how to get the name of the target (used by the view to store the name of the primary object the feed links to). (default is nil)
      # * +scoping_object?+ - Boolean - If true, this object will become the scoping object for all feedables descending from it. eg. a Project is a scoping object for all discussions, comments, and writeboards within the project.
      # * +parent+ - Specifies the code to execute to traverse up the feedable chain in search of any scoping objects
      #
      # === Delegate Options
      #
      # * +actions+ - overrides the :created, :updated, and :destroyed actions with custom actions (must be set if the +delegate+ option is used)
      # * +references+ - provides feeds with a surrogate feedable when the object itself isn't the focus of the feed. (must be set if the +delegate+ option is used)
      #
      # === Aggregate Options
      #
      # * +action+ - specifies the action group the aggregate feed should belong to (must be set if the +aggregate+ option is used)
      # * +references+ - provides aggregate feeds with a feedable by which to group this object's feeds. (must be set if the +aggregate+ option is used)
      # * +component_reference+ - specifies the object that is referenced by the aggregated feed component. This needs to be the object that the feed "happens to" (e.g. a label is applied to an item). We use this when determining how to handle subsequent update and destroy actions. (aggregated feed components are used to store each action that is referenced by an aggregate feed) (default is self)
      # * +component_secondary_reference+ - specifies an optional secondary object that is referenced by an aggregated feed component. For example, the item that a label is being applied to (default is nil)
      # * +component_reference_name+ - specifies how to get the name of the reference (used when a component is destroyed). (default is component_reference.name)
      # * +component_secondary_reference_name+ - specifies how to get the name of the secondary_reference (used when the secondary_reference is destroyed). (default is component_secondary_reference.name)
      def acts_as_feedable(options = {})
        extend ClassMethods unless (class << self; included_modules; end).include?(ClassMethods)
        include InstanceMethods unless included_modules.include?(InstanceMethods)
        
        # Sanity Check
        options.assert_valid_keys(:scoping_object?, :parent, :keep_feeds_when_destroyed, :target_name, :delegate, :aggregate)
        
        raise 'target_name option must be set if the keep_feeds_when_destroyed option is used' if options.key?(:keep_feeds_when_destroyed) && !options.key?(:target_name)
        
        options[:delegate].assert_valid_keys(:actions, :references) if options[:delegate].present?
        raise 'actions option must be set if the delegate option is used' if options[:delegate].is_a?(Hash) && options[:delegate][:actions].blank?
        raise 'references option must be set if the delegate option is used' if options[:delegate].is_a?(Hash) && options[:delegate][:references].blank?
        
        options[:aggregate].assert_valid_keys(:action, :references, :component_reference, :component_secondary_reference, :component_reference_name, :component_secondary_reference_name) if options[:aggregate].present?
        raise 'action option must be set if the aggregate option is used' if options[:aggregate].is_a?(Hash) && options[:aggregate][:action].blank?
        raise 'references option must be set if the aggregate option is used' if options[:aggregate].is_a?(Hash) && options[:aggregate][:references].blank?
        
        options.reverse_merge!(:keep_feeds_when_destroyed => false, :delegate => {}, :aggregate => {})
        
        self.feed_options = options
        
        class_eval <<-EOV
        
          def keep_feeds_when_destroyed?
            #{options[:keep_feeds_when_destroyed]}
          end
          
          def feedable
            if delegating?
              #{options[:delegate][:references]}
            elsif aggregating?
              #{options[:aggregate][:references]}
            else
              self
            end
          end
          
          def target_name
            #{options[:target_name] || 'nil'}
          end

          def parent_feedable
            #{options[:parent] || 'nil'}
          end
          
          # Aggregate Feed Methods
          
          def component_reference
            #{options[:aggregate][:component_reference] || 'self'}
          end
          
          def component_reference_name
            #{options[:aggregate][:component_reference_name] || 'component_reference.name'}
          end
          
          def component_secondary_reference
            #{options[:aggregate][:component_secondary_reference] || 'nil'}
          end
          
          def component_secondary_reference_name
            #{options[:aggregate][:component_secondary_reference_name] || 'component_secondary_reference.try(:name)'}
          end
          # END Aggregate Feed Methods
        EOV
        
      end
    end
    
    module ClassMethods
      def self.extended(base)
        base.after_create :add_created_feed
        base.after_update :add_updated_feed
        base.before_destroy :setup_destroyed_feed_if_keeping_feeds
        base.after_destroy :add_destroyed_feed, :destroy_scoped_feeds
        
        base.cattr_accessor :feed_options
        base.has_many :feeds, :as => :feedable
      end
      
      def create_with_feed(user, *args)
        options = args.extract_options!
        options.merge!(:feed_initiator_id => user.id)
        return create(options)
      end      
    end
    
    module InstanceMethods
      attr_accessor :feed_initiator_id

      def acts_like_feedable?
        true
      end

      # Returns the scoping object for this object
      def scoping_object
        scoping_ancestor || parent_feedable
      end
      
      # Returns true if this object is a scoping object
      def scoping_object?
        self.feed_options[:scoping_object?] == true
      end
            
      def delegating?
        self.feed_options[:delegate][:actions].present? && self.feed_options[:delegate][:references].present?
      end
      
      def delegate_action_for(action)
        self.feed_options[:delegate][:actions][action.to_sym] || action.to_s
      end
      
      def aggregating?
        self.feed_options[:aggregate][:action].present? && self.feed_options[:aggregate][:references].present?
      end
      
      def aggregate_action
        self.feed_options[:aggregate][:action]
      end
      # ActiveRecord Wrappers with initiators
              
      def save_with_feed(user, *args)
        self.feed_initiator_id = user.id
        return save(*args)
      end
      
      def save_with_feed!(user, *args)
        self.feed_initiator_id = user.id
        return save!(*args)
      end
      
      def update_attributes_with_feed(user, *args)
        self.feed_initiator_id = user.id
        return update_attributes(*args)
      end
      
      def update_attributes_with_feed!(user, *args)
        self.feed_initiator_id = user.id
        return update_attributes(*args)
      end
      
      def destroy_with_feed(user, *args)
        self.feed_initiator_id = user.id
        return destroy(*args)
      end
      
      def with_feed(user)
        self.feed_initiator_id = user.id
        return self
      end
      
      # END ActiveRecord Wrappers with initiators
    
      # Adds a custom feed for this object with the given +action+ and +initiator+
      def add_custom_feed(action, initiator, options = {})          
        feed = Feed.new(:initiator => initiator, :action => action, :scoping_object => scoping_object, :feedable => self, :target_name => target_name)

        feed.initial_instance_level_permission_map = options[:map] if options[:map]
        
        feed.save!
      end
      
      private

      # Searches up the chain of parent_feedables until it hits a scoping object and returns it
      # If none is found, returns nil
      def scoping_ancestor
        if parent_feedable && parent_feedable.acts_like?(:feedable)
          if parent_feedable.scoping_object?
            parent_feedable
          else
            parent_feedable.send(:scoping_ancestor)
          end
        end                
      end
                  
      # Creates a feed about the creation of the feedable  
      def add_created_feed
        return unless feed_initiator_id
        
        if aggregating?
          update_aggregate_feed(:added)
        elsif delegating?
          create_feed_with_defaults(:action => delegate_action_for('created'))
        else
          create_feed_with_defaults(:action => 'created')
        end
        clear_initiator
      end
      
      # Creates a feed about the update of the feedable  
      def add_updated_feed
        return unless feed_initiator_id
                  
        if aggregating?
          update_aggregate_feed(:updated)
        elsif delegating?
          create_feed_with_defaults(:action => delegate_action_for('updated'))
        else
          create_feed_with_defaults(:action => 'updated')
        end
        clear_initiator
      end
      
      # Creates a feed about the deletion of the feedable. 
      # If the feed isn't aggregated then it deletes all existing feeds related to that object.
      def add_destroyed_feed                  
        if aggregating?
          update_aggregate_feed(:removed) if feed_initiator_id
        elsif delegating?
          create_feed_with_defaults(:action => delegate_action_for('destroyed')) if feed_initiator_id
        elsif !keep_feeds_when_destroyed?
          Feed.destroy_all(:feedable_type => self.class.to_s, :feedable_id => id)
        end
        clear_initiator
      end
      
      # Create the destroyed feed before the feedable is destroyed so it gets the correct permission mappings
      def setup_destroyed_feed_if_keeping_feeds
        if keep_feeds_when_destroyed? && feed_initiator_id  
          create_feed_with_defaults(:action => 'destroyed')
        end
      end
      
      # Destroy all feeds which are scoped to the feedable.
      # This will prevent feeds from not rendering because the feedable has been destroyed.
      def destroy_scoped_feeds
        unless aggregating?
          Feed.destroy_all(:scoping_object_type => self.class.to_s, :scoping_object_id => id)
        end
      end
      
      def create_feed_with_defaults(options)
        Feed.create(options.merge(:initiator_id => feed_initiator_id, :scoping_object => scoping_object, :feedable => feedable, :target_name => target_name))
      end
      
      # Called when the feedable generates aggregate feeds.
      #
      # Increments one of the counts depending on whether the feedable is created or destroyed
      # and creates an FeedAggregatedComponent to represent the feedable.
      #
      # eg. When a label is created update the count in the project_label_created feed and create a FeedAggregatedComponent which
      # points to the label.
      def update_aggregate_feed(direction)
        feed = find_existing_aggregate_feed || create_aggregate_feed
      
        if direction.eql?(:added)
          aggregated_component_addition(feed)
        elsif direction.eql?(:updated)
          aggregated_component_update(feed)
        else
          aggregated_component_removal(feed)
        end
      end

      def aggregated_component_addition(feed)
        # If the aggregated component was already removed today, just remove the destroyed
        # components to zero out the feed.
        #
        # Else add a created FeedAggregatedComponent instead
        if remove_todays_destroyed_feed(feed, component_reference)
          # Get rid of the feed completely if there are no more FeedAggregatedComponents
          feed.destroy if feed.added_count == 0 && feed.updated_count == 0 && feed.removed_count == 0
        else          
          feed.increment!(:added_count)
          create_component(feed, 'created')
        end
      end

      def aggregated_component_update(feed)
        # Only add an 'updated' FeedAggregatedComponent if a matching FeedAggregatedComponent wasn't created lately or updated today.
        unless FeedAggregatedComponent.created_recently(feed, component_reference, component_secondary_reference) || FeedAggregatedComponent.updated_today(feed, component_reference, component_secondary_reference)
          feed.increment!(:updated_count)
          create_component(feed, 'updated')
        end
      end

      def aggregated_component_removal(feed)
        # If the aggregated component was already created today, just remove the created
        # and updated components to zero out the feed.
        #
        # Else get rid of any updated FeedAggregatedComponents from today and add a destroyed
        # FeedAggregatedComponent instead
        remove_todays_updated_feed(feed, component_reference)
        if remove_todays_created_feed(feed, component_reference)
          # Get rid of the feed completely if there are no more FeedAggregatedComponents
          feed.destroy if feed.added_count == 0 && feed.updated_count == 0 && feed.removed_count == 0
        else
          feed.increment!(:removed_count)
          create_component(feed, 'destroyed')
        end
      end

      # Remove a 'created' FeedAggregatedComponent that was created today for the provided
      # *component_reference* and return true if it was removed
      def remove_todays_created_feed(feed, component_reference)
        if feedable_aggregated_component = FeedAggregatedComponent.created_today(feed, component_reference, component_secondary_reference)
          feed.decrement!(:added_count)
          feedable_aggregated_component.destroy
          
          return true
        end
      end

      # Remove an 'updated' FeedAggregatedComponent that was created today for the provided
      # *component_reference* and return true if it was removed
      def remove_todays_updated_feed(feed, component_reference)
        if feedable_aggregated_component = FeedAggregatedComponent.updated_today(feed, component_reference, component_secondary_reference)
          feed.decrement!(:updated_count)
          feedable_aggregated_component.destroy

          return true
        end
      end

      # Remove a 'destroyed' FeedAggregatedComponent that was created today for the provided
      # *component_reference* and return true if it was removed
      def remove_todays_destroyed_feed(feed, component_reference)
        if feedable_aggregated_component = FeedAggregatedComponent.destroyed_today(feed, component_reference, component_secondary_reference)
          feed.decrement!(:removed_count)
          feedable_aggregated_component.destroy

          return true
        end
      end
      
      # Find an existing aggregate feed which was created on *date*
      def find_existing_aggregate_feed(date = Date.today)
        Feed.where("initiator_id = ? AND feedable_type = ? AND feedable_id = ? AND action = ? AND created_at > ? AND created_at < ?", feed_initiator_id, feedable.class.to_s, feedable.id, aggregate_action, date, date + 1.day).first
      end
      
      def create_aggregate_feed
        aggregate_feed = Feed.new(:initiator_id => feed_initiator_id, :scoping_object => scoping_object, :feedable => feedable, :target_name => target_name, :action => aggregate_action)

        # Change permission mapping to respect permissions of object being aggregated.
        aggregate_feed.view_permission = self.view_permission if acts_like?(:joinable_component)
      
        aggregate_feed.save!
      
        return aggregate_feed
      end
      
      # Creates a component to reflect the *action* of the feedable.
      def create_component(feed, action)
        FeedAggregatedComponent.create(:action => action, :feed => feed, :reference => component_reference, :reference_name => component_reference_name, :secondary_reference => component_secondary_reference, :secondary_reference_name => component_secondary_reference_name)
      end

      # Clears the initiator id from the feedable
      def clear_initiator
        self.feed_initiator_id = nil
      end
    end
  end
end