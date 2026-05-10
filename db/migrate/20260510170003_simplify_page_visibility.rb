class SimplifyPageVisibility < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :visibility, :integer, default: 0, null: false
    add_index  :pages, :visibility

    reversible do |dir|
      dir.up do
        Page.reset_column_information
        Page.where(published: true).update_all(visibility: 1)  # public
        Page.where(published: false).update_all(visibility: 0) # draft

        # Old PageAccess(mode: hidden) semantics no longer apply — those rows
        # described "hide this otherwise-public page from a specific investor",
        # which the new model doesn't have. Wipe them; admins re-grant access
        # explicitly under the new private/allowlist semantics.
        execute "DELETE FROM page_accesses"
      end
    end

    remove_column :pages, :published, :boolean, default: false, null: false
    remove_column :page_accesses, :mode, :integer, default: 0, null: false
  end
end
