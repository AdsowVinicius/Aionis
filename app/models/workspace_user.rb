class WorkspaceUser < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  enum :role, { member: "member", admin: "admin", owner: "owner" }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :workspace_id }
end
