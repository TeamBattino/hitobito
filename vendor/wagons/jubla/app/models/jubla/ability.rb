module Jubla::Ability
  extend ActiveSupport::Concern
  
  included do
    alias_method_chain :define_abilities, :jubla
  end
  
  def define_abilities_with_jubla
    define_abilities_without_jubla
    
    customize_for_closed_events
    
    define_census_abilities

    define_event_abilities

    define_course_conditions_abilities
  end
  
  private

  # important, cannot statements have to go at the end to override previous can statements
  # if can statements are missing, returning false from cannot statements does not allow the action
  def customize_for_closed_events
    cannot [:application_market, :update, :destroy, :qualify], Event do |event|
      is_closed_course?(event) && !admin
    end

    cannot [:create, :update, :destroy], Event::Participation do |participation|
      is_closed_course?(participation.event) && !admin
    end

    cannot :manage, Event::Role do |event_role|
      is_closed_course?(event_role.event) && !admin
    end
  end

  def define_census_abilities
    can :evaluate_census, Group do |group|
      !external?
    end
    
    # this is called on the state group
    can :remind_census, Group do |group|
      layers_full.present? && 
      contains_any?(layers_full, collect_ids(group.layer_groups))
    end
    
    can :approve_population, Group do |group|
      group.kind_of?(Group::Flock) &&
      layers_full.present? && 
      layers_full.include?(group.id)
      contains_any?(layers_full, collect_ids(group.layer_groups))
    end
    
    can :create_member_counts, Group do |group|
      group.kind_of?(Group::Flock) &&
      layers_full.present? && 
      contains_any?(layers_full, collect_ids(group.layer_groups))
    end
    
    can :update_member_counts, Group do |group|
      group.kind_of?(Group::Flock) &&
      layers_full.present? && 
      user.roles.any?{ |r| r.kind_of?(Group::StateAgency::Leader) || 
                           r.kind_of?(Group::FederalBoard::Member) } &&
      contains_any?(layers_full, collect_ids(group.layer_groups))
    end
    
    if admin
      can :manage, Census
    end
  end
  
  def is_closed_course?(event)
    event.kind_of?(Event::Course) && event.closed?
  end

  def define_event_abilities
    if admin
      can :manage, Event::Camp::Kind
    end
  end

  def define_course_conditions_abilities
    can :index_event_course_conditions, Group do |group|
      can_manage_course_event_conditions?(group)
    end
    
    can :manage, Event::Course::Condition do |course_condition|
      can_manage_course_event_conditions?(course_condition.group)
    end
  end

  def can_manage_course_event_conditions?(group)
    layers_full.present? &&
      contains_any?(layers_full, collect_ids(group.layer_groups))
  end
  
end
