# frozen_string_literal: true

#  Copyright (c) 2022, Schweizer Wanderwege. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

module ContactableResource
  extend ActiveSupport::Concern

  included do
    attribute :label, :string
    attribute :public, :boolean

    attribute :contactable_id, :integer
    attribute :contactable_type, :string

    alias_method :index_ability, :contactable_ability
    alias_method :write_ability, :contactable_ability
  end

  def contactable_ability
    ContactableAbilityCache.get_or_build(current_ability)
  end

  private

  # building the `JsonApi::ContactAbility` as currently implemented is very expensive.
  # we cache it so it can be used from the other instances of this resource.
  class ContactableAbilityCache < ActiveSupport::CurrentAttributes
    attribute :cache

    def get_or_build(main_ability)
      self.cache ||= {}
      self.cache[main_ability.user] ||= contact_ability(main_ability)
    end

    private

    def contact_ability(main_ability)
      JsonApi::ContactAbility.new(main_ability, people_scope(main_ability.user))
    end

    def people_scope(user)
      Person.accessible_by(PersonReadables.new(user))
    end
  end
end

