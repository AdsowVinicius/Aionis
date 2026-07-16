module Workspaces
  class BaseController < ApplicationController
    before_action :require_workspace!
    before_action :set_audit_workspace

    private

    def set_audit_workspace
      Current.workspace = current_workspace
    end
  end
end
