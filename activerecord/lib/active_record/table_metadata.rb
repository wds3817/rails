# frozen_string_literal: true

module ActiveRecord
  class TableMetadata # :nodoc:
    delegate :foreign_type, :foreign_key, :join_primary_key, :join_foreign_key, to: :reflection, prefix: :association

    def initialize(klass, arel_table, reflection = nil, types = klass)
      @klass = klass
      @types = types
      @arel_table = arel_table
      @reflection = reflection
    end

    def arel_attribute(column_name)
      if klass
        klass.arel_attribute(column_name, arel_table)
      else
        arel_table[column_name]
      end
    end

    def type(column_name)
      types.type_for_attribute(column_name)
    end

    def has_column?(column_name)
      klass&.columns_hash.key?(column_name)
    end

    def associated_with?(table_name)
      klass&._reflect_on_association(table_name) || klass&._reflect_on_association(table_name.singularize)
    end

    def associated_table(table_name)
      reflection = klass._reflect_on_association(table_name) || klass._reflect_on_association(table_name.singularize)

      if !reflection && table_name == arel_table.name
        return self
      end

      reflection ||= yield table_name if block_given?

      if reflection && !reflection.polymorphic?
        association_klass = reflection.klass
        arel_table = association_klass.arel_table.alias(table_name)
        TableMetadata.new(association_klass, arel_table, reflection)
      else
        type_caster = TypeCaster::Connection.new(klass, table_name)
        arel_table = Arel::Table.new(table_name, type_caster: type_caster)
        TableMetadata.new(nil, arel_table, reflection, type_caster)
      end
    end

    def polymorphic_association?
      reflection&.polymorphic?
    end

    def reflect_on_aggregation(aggregation_name)
      klass&.reflect_on_aggregation(aggregation_name)
    end
    alias :aggregated_with? :reflect_on_aggregation

    def predicate_builder
      if klass
        predicate_builder = klass.predicate_builder.dup
        predicate_builder.instance_variable_set(:@table, self)
        predicate_builder
      else
        PredicateBuilder.new(self)
      end
    end

    private
      attr_reader :klass, :types, :arel_table, :reflection
  end
end
