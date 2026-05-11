class CreateAttributeOptions < ActiveRecord::Migration[8.1]
  class MigrationAttributeDefinition < ActiveRecord::Base
    self.table_name = "attribute_definitions"
  end

  class MigrationAttributeOption < ActiveRecord::Base
    self.table_name = "attribute_options"
  end

  def up
    create_table :attribute_options do |t|
      t.references :attribute_definition, null: false, foreign_key: true
      t.string  :value, null: false
      t.string  :label, null: false
      t.string  :color
      t.integer :sort_order, default: 0, null: false
      t.timestamps

      t.index [ :attribute_definition_id, :value ], unique: true,
              name: "index_attribute_options_on_definition_and_value"
      t.index [ :attribute_definition_id, :sort_order ],
              name: "index_attribute_options_on_definition_and_sort"
    end

    MigrationAttributeDefinition.reset_column_information

    MigrationAttributeDefinition.where.not(options: nil).find_each do |defn|
      now = Time.current
      rows = Array(defn.options).each_with_index.filter_map do |opt, idx|
        next if opt.blank? || opt["value"].blank?

        {
          attribute_definition_id: defn.id,
          value:      opt["value"].to_s,
          label:      (opt["label"].presence || opt["value"]).to_s,
          color:      opt["color"].presence,
          sort_order: idx,
          created_at: now,
          updated_at: now
        }
      end
      MigrationAttributeOption.insert_all!(rows) if rows.any?
    end

    remove_column :attribute_definitions, :options
  end

  def down
    add_column :attribute_definitions, :options, :json

    MigrationAttributeDefinition.reset_column_information
    MigrationAttributeOption.reset_column_information

    MigrationAttributeOption.order(:attribute_definition_id, :sort_order)
      .group_by(&:attribute_definition_id).each do |defn_id, opts|
      payload = opts.map { |o| { "value" => o.value, "label" => o.label, "color" => o.color }.compact }
      MigrationAttributeDefinition.where(id: defn_id).update_all(options: payload.to_json)
    end

    drop_table :attribute_options
  end
end
