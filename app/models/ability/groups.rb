module Ability::Groups

  def define_groups_abilities
    can [:read, :deleted_subgroups], Group

    can :show_details, Group do |group|
      can_detail_group?(group)
    end

    if modify_permissions?
      can :create, Group do |group|
        # BEWARE! Always pass a Group instance to create for correct abilities
        group.parent.present? &&
        can_create_group?(group.parent) &&
        !group.parent.deleted?
      end

      can :destroy, Group do |group|
        can_destroy_group?(group)
      end

      can :update, Group do |group|
        can_update_group?(group) && !group.deleted?
      end

      can :move, Group do |group, parent|
        can_destroy_group?(group) &&
        can_create_group?(parent) &&
        parent != group.parent
      end

      can :reactivate, Group do |group|
        can_update_group?(group)
      end

      if layers_full.present?
        can :modify_superior, Group do |group|
          contains_any?(layers_full, collect_ids(group.upper_layer_groups))
        end
      end

    end

    can :index_people, Group do |group|
      can_index_people?(group)
    end

    can :index_full_people, Group do |group|
      groups_group_full.include?(group.id) ||
        (layers_read.present? &&
         contains_any?(layers_read, collect_ids(group.layer_groups)))
    end

    can :index_deep_full_people, Group do |group|
      layers_read.present? &&
      contains_any?(layers_read, collect_ids(group.layer_groups))
    end
    
    # can index people that are not visible from above. eg. children, affiliates, ...
    can :index_local_people, Group do |group|
      groups_group_read.include?(group.id) ||
      (layers_read.present? &&
       layers_read.include?(group.layer_group.id))
    end

    can :index_events, Group
    
    can :index_mailing_lists, Group
    
    can :show_deleted, Group do |group|
      !external?
    end

    ### ROLES

    if modify_permissions?
      can :create, Role do |role|
        # BEWARE! Always pass a Role instance to create for correct abilities
        !role.restricted && can_update_group?(role.group) && !role.group.deleted?
      end

      can :update, Role do |role|
        can_modify_role?(role)
      end

      can :destroy, Role do |role|
        can_modify_role?(role) &&
        # user may not destroy his roles that give him the destroy permissions
        (role.person_id != user.id || !contains_any?([:layer_full, :group_full], role.permissions))
      end
    end

  end

  private

  def can_update_group?(group)
    # user has group_full for this group
    (groups_group_full.include?(group.id) || can_create_group?(group))
  end

  def can_create_group?(group)
    layers_full.present? &&
     # user has layer_full, group in same layer or below
     contains_any?(layers_full, collect_ids(group.layer_groups))
  end

  def can_destroy_group?(group)
    can_create_group?(group) &&
    !(groups_layer_full.include?(group.id) || layers_full.include?(group.id))
  end

  def can_detail_group?(group)
    groups_group_read.include?(group.id) ||
    (layers_read.present? && contains_any?(layers_read, collect_ids(group.layer_groups)))
  end

  def can_modify_role?(role)
    # restricted roles may only be modified in a special place
    !role.class.restricted && (

    # user has group_full, role in same group
    groups_group_full.include?(role.group.id) ||

    (layers_full.present? && (
      # user has layer_full, role in same layer
      layers_full.include?(role.group.layer_group.id) ||

      # user has layer_full, role below layer and visible_from_above
      (role.class.visible_from_above &&
       contains_any?(layers_full, collect_ids(role.group.hierarchy)))
    )))
  end
end
