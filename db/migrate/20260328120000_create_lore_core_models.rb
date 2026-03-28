class CreateLoreCoreModels < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :pat_digest, null: false

      t.timestamps
    end
    add_index :users, :username, unique: true

    create_table :repos do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description, null: false, default: ""
      t.text :tags, null: false, default: "[]"
      t.string :path, null: false
      t.text :embedding
      t.datetime :last_pushed_at

      t.timestamps
    end
    add_index :repos, %i[owner_id name], unique: true
    add_index :repos, :path, unique: true

    create_table :stars do |t|
      t.references :user, null: false, foreign_key: true
      t.references :repo, null: false, foreign_key: true

      t.timestamps
    end
    add_index :stars, %i[user_id repo_id], unique: true
  end
end
