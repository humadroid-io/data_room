class Admin::AttributeDefinitionsController < Admin::BaseController
  before_action :set_definition, only: %i[edit update destroy]

  def index
    @grouped = AttributeDefinition.order(:resource_type, :sort_order, :label)
                                   .group_by(&:resource_type)
  end

  def new
    @definition = AttributeDefinition.new(
      resource_type: params[:resource_type] || "Customer",
      data_type:     :string
    )
  end

  def edit; end

  def create
    @definition = AttributeDefinition.new(definition_params)
    if @definition.save
      redirect_to admin_attribute_definitions_path, notice: "Attribute defined."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @definition.update(definition_params)
      redirect_to admin_attribute_definitions_path, notice: "Attribute updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @definition.destroy
    redirect_to admin_attribute_definitions_path, notice: "Attribute removed."
  end

  private

  def set_definition
    @definition = AttributeDefinition.find(params[:id])
  end

  def definition_params
    raw = params.require(:attribute_definition).permit(
      :resource_type, :key, :label, :description, :data_type,
      :required, :capture_on_snapshot, :sort_order, :options_json
    )
    options_json = raw.delete(:options_json)
    if options_json.present?
      begin
        raw[:options] = JSON.parse(options_json)
      rescue JSON::ParserError
        raw[:options] = []
      end
    end
    raw
  end
end
