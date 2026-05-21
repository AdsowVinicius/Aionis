class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :workspace_users, dependent: :destroy
  has_many :workspaces, through: :workspace_users
  has_many :owned_workspaces, class_name: "Workspace", foreign_key: :owner_id, dependent: :destroy

  validates :name, presence: true
end
