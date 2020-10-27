class Api::V7::DepositsController < Api::BaseController
  prepend_before_filter :load_deposit, only: [:show, :destroy]
  before_filter :authenticate_user_from_token!, :except => [:index, :show]
  load_and_authorize_resource :except => [:create, :show, :index]
  load_resource :except => [:create]

  swagger_controller :deposits, "Deposits"

  swagger_api :index do
    summary 'Returns all deposits, sorted by date'
    param :query, :message_type, :string, :optional, "Filter by message_type"
    param :query, :state, :prefix, :optional, "Filter by DOI prefix"
    param :query, :source_token, :string, :optional, "Filter by source_token"
    param :query, :state, :string, :optional, "Filter by state"
    response :ok
    response :unprocessable_entity
    response :not_found
  end

  swagger_api :show do
    summary 'Returns deposit by ID'
    param :path, :id, :string, :required, "Deposit ID"
    response :ok
    response :unprocessable_entity
    response :not_found
  end

  def create
    @deposit = Deposit.new(safe_params)
    authorize! :create, @deposit

    if @deposit.save
      @status = "accepted"
      @deposit = @deposit.decorate
      render "show", :status => :accepted
    else
      render json: { meta: { status: "error", error: @deposit.errors }, deposit: {}}, status: :bad_request
    end
  end

  def show
    @deposit = @deposit.decorate
  end

  def index
    collection = Deposit.all

    collection = collection.where(message_type: params[:message_type]) if params[:message_type].present?
    collection = collection.where(prefix: params[:prefix]) if params[:prefix].present?
    collection = collection.where(source_token: params[:source_token]) if params[:source_token].present?
    collection = collection.where(source_id: params[:source_id]) if params[:source_id].present?
    collection = collection.query(params[:q]) if params[:q].present?

    if params[:state]
      # NB this is coupled to deposit.rb's state machine.
      states = { "waiting" => 0, "working" => 1, "failed" => 2, "done" => 3 }
      state = states.fetch(params[:state], 0)
      collection = collection.where(state: state)
    end

    page = params[:page] && params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = params[:per_page] && (0..1000).include?(params[:per_page].to_i) ? params[:per_page].to_i : 1000
    collection = collection.order("updated_at DESC").paginate(per_page: per_page, page: page)
    @deposits = collection.decorate
  end

  def destroy
    if @deposit.destroy
      render json: { meta: { status: "deleted" }, deposit: {} }, status: :ok
    else
      render json: { meta: { status: "error", error: "An error occured." }, deposit: {}}, status: :bad_request
    end
  end

  protected

  def load_deposit
    @deposit = Deposit.where(uuid: params[:id]).first

    fail ActiveRecord::RecordNotFound unless @deposit.present?
  end

  private

  def safe_params
    nested_params = [:pid, :name, { author: [:given, :family, :literal, :"ORCID"] }, :title, :"container-title", :issued, :"URL", :"DOI", :registration_agency, :publisher_id, :type, :tracked, :active]
    params.require(:deposit).permit(:uuid, :message_type, :message_action, :source_token, :callback, :prefix, :subj_id, :obj_id, :relation_type_id, :source_id, :publisher_id, :total, :occurred_at, :provenance_url, :timestamp, subj: nested_params, obj: nested_params)
  end
end
