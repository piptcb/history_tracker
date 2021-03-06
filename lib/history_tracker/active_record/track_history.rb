module HistoryTracker
  module ActiveRecord
    module TrackHistory
      extend ActiveSupport::Concern

      module ClassMethods
        def track_history(options = {})
          return if track?

          delegate  :track_history?, :tracked_columns, :non_tracked_columns,
                    to: 'self.class'
          class_attribute :track_history_per_model, instance_writer: false
          self.track_history_per_model = true

          setup_tracking!(options)

          extend HistoryTracker::ActiveRecord::ClassMethods
          include HistoryTracker::ActiveRecord::InstanceMethods
        end

        def track?
          self.included_modules.include?(HistoryTracker::ActiveRecord::InstanceMethods)
        end

        def tracked_columns
          @tracked_columns ||= (column_names - non_tracked_columns)
        end

        def non_tracked_columns
          return @non_tracked_columns if @non_tracked_columns

          if history_options[:only].present?
            except = column_names - history_options[:only].flatten.map(&:to_s)
          else
            except = HistoryTracker.ignored_attributes
            except |= history_options[:except] if history_options[:except]
          end
          
          @non_tracked_columns = except
        end

        private
        def setup_tracking!(options)
          track_options!(options)
          track_callback!
        end

        def track_options!(options)
          options[:scope]   ||= self.name.split('::').last.underscore
          options[:except]  ||= []
          options[:except]    = options[:except].collect(&:to_s)
          options[:only]    ||= []
          options[:only]      = options[:only].collect(&:to_s)
          options[:include] ||= []
          options[:methods] ||= []
          options[:on]      ||= [:create, :update, :destroy]
          options[:changes] ||= nil

          class_attribute :history_options, instance_writer: false
          self.history_options = options

          include_reflections  = []
          history_options[:include].each do |pair|
            if pair.is_a?(Hash)
              association_name, association_fields = pair.keys.first, pair.values.first
            else
              association_name, association_fields = pair, nil
            end

            hash       = {}
            reflection = reflect_on_association(association_name)
            hash[reflection] = association_fields
            include_reflections << hash
          end
          class_attribute :include_reflections
          self.include_reflections = include_reflections
        end

        def track_callback!
          after_create   :track_create   if history_options[:on].include?(:create)
          before_update  :track_update   if history_options[:on].include?(:update)
          before_destroy :track_destroy  if history_options[:on].include?(:destroy)
        end
      end
    end
  end
end