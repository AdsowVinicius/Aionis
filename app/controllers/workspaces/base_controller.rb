module Workspaces
  class BaseController < ApplicationController
    before_action :require_workspace!
  end
end
