class WorksController < ApplicationController
  before_filter :load_work, only: [:show, :edit, :update, :destroy]
  before_filter :new_work, only: [:create]
  load_and_authorize_resource
  skip_authorize_resource :only => [:show, :index]

  def index
    @page = (params[:page] || 1).to_i
    @q = params[:q]
    @class_name = params[:class_name]
    @publisher = cached_publisher(params[:publisher_id])
    @source = cached_source(params[:source_id])
    @sort = Source.active.where(name: params[:sort]).first
    @relation_type = cached_relation_type(params[:relation_type_id])
  end

  def show
    format_options = params.slice :events, :source

    @groups = Group.order("id")
    @page = params[:page] || 1
    @source = cached_source(params[:source_id])
    @relation_type = cached_relation_type(params[:relation_type_id])
    @contributor_role = cached_contributor_role(params[:contributor_role_id])
    render :show
  end

  def edit
    render :show
  end

  # PUT /works/:id(.:format)
  def update
    @work.update_attributes(safe_params)
    render :show
  end

  def destroy
    @work.destroy
    redirect_to works_path
  end

  protected

  def load_work
    # Load one work given query params
    id_hash = get_id_hash(params[:id])
    if id_hash.respond_to?("key")
      key, value = id_hash.first
      @work = Work.where(key => value).first
    else
      @work = nil
    end
    fail ActiveRecord::RecordNotFound unless @work.present?
  end

  def new_work
    @work = Work.new(safe_params)
  end

  private

  def safe_params
    params.require(:work).permit(:doi, :title, :pmid, :pmcid, :canonical_url, :year, :month, :day, :publisher_id, :work_type_id, :arxiv, :scp, :wos, :ark, :dataone, :tracked)
  end
end
