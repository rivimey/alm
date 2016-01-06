class ContributorsController < ApplicationController
  before_filter :load_contributor, only: [:show, :destroy]
  before_filter :load_index, only: [:index]
  load_and_authorize_resource
  skip_authorize_resource :only => [:show, :index]

  def index
  end

  def show
    @page = (params[:page] || 1).to_i
    @source = Source.active.where(name: params[:source_id]).first
    @sort = Source.active.where(name: params[:sort]).first
  end

  def destroy
    @contributor.destroy
    redirect_to contributors_path
  end

  protected

  def load_contributor
    pid = get_pid(params[:id])
    @contributor = Contributor.where(pid: pid).first
    fail ActiveRecord::RecordNotFound unless @contributor.present?
  end

  def load_index
    collection = Contributor
    collection = collection.query(params[:q]) if params[:q]
    collection = collection.order("contributors.created_at DESC")
    @contributors = collection.paginate(page: (params[:page] || 1).to_i)
  end

  def get_pid(id)
    return nil unless id.present?
    id.starts_with?('http') ? id.gsub(/(http|https):\/+(\w+)/, '\1://\2') : "http://#{id}"
  end

  private

  def safe_params
    params.require(:contributor).permit(:given_names, :family_name, :pid, :orcid)
  end
end
