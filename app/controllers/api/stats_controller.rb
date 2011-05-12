class Api::StatsController < Api::ApiController
  before_filter :ensure_context, :only => :create
  before_filter :ensure_signed, :only => :create
  
  def create
    return unless ensure_params(:unique)

    render :nothing => true
  end

end