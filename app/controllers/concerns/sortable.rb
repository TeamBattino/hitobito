# Sort functionality for the index table.
# Extracted into an own module for convenience.
module Sortable
  extend ActiveSupport::Concern

  # Adds a :sort_mappings class attribute.
  included do
    # Define a map of (virtual) attributes to SQL order expressions.
    # May be used for sorting table columns that do not appear directly
    # in the database table. E.g., map :city_id => 'cities.name' to
    # sort the displayed city names.
    class_attribute :sort_mappings_with_indifferent_access
    self.sort_mappings = {}

    helper_method :sortable?

    alias_method_chain :list_entries, :sort
  end

  module ClassMethods
    def sort_mappings=(hash)
      self.sort_mappings_with_indifferent_access = hash.with_indifferent_access
    end

    # Puts null and empty strings last
    def null_safe_sort(sort_expression)
      table_attr, direction = sort_expression.split
      null_safe = 'CASE'
      null_safe << " WHEN #{table_attr} IS NULL THEN 1"
      null_safe << " WHEN #{table_attr} = '' THEN 1"
      null_safe << " ELSE 0 END #{direction}"
      [null_safe, sort_expression]
    end
  end

  private

  # Enhance the list entries with an optional sort order.
  def list_entries_with_sort
    if sorting?
      list_entries_without_sort.reorder(sort_expression)
    else
      list_entries_without_sort
    end
  end

  def sorting?
    params[:sort].present? && sortable?(params[:sort])
  end

  # Return sort columns from defined mappings or as null_safe_sort from parameter.
  def sort_columns
    sort_mappings_with_indifferent_access[params[:sort]] ||
      self.class.null_safe_sort("#{model_class.table_name}.#{params[:sort]}")
  end

  # Return the sort expression to be used in the list query.
  def sort_expression
    Array(sort_columns).collect { |c| "#{c} #{sort_dir}" }.join(', ')
  end

  # The sort direction, either 'asc' or 'desc'.
  def sort_dir
    params[:sort_dir] == 'desc' ? 'desc' : 'asc'
  end

  # Returns true if the passed attribute is sortable.
  def sortable?(attr)
    model_class.column_names.include?(attr.to_s) ||
    sort_mappings_with_indifferent_access.include?(attr)
  end
end
