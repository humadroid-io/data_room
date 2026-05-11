class Admin::AttributeDefinitionsController < Admin::BaseController
  before_action :set_definition, only: %i[show edit update destroy]

  def index
    @grouped = AttributeDefinition.order(:resource_type, :sort_order, :label)
                                   .group_by(&:resource_type)
  end

  def show
    if @definition.resource_type == "Customer"
      @resource_count = Customer.count
      @usage_count    = Customer
        .where("json_extract(custom_attributes, ?) IS NOT NULL",
               "$.#{Customer.sanitize_json_key(@definition.key)}")
        .count
    end
  end

  def new
    @definition = AttributeDefinition.new(
      resource_type: params[:resource_type] || "Customer",
      data_type:     :string
    )
    @definition.attribute_options.build
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
    params.require(:attribute_definition).permit(
      :resource_type, :key, :label, :description, :data_type,
      :required, :capture_on_snapshot, :sort_order,
      attribute_options_attributes: [ :id, :value, :label, :color, :sort_order, :_destroy ]
    )
  end
end
