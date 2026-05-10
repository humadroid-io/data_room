class Admin::EventsController < Admin::BaseController
  before_action :set_event, only: %i[edit update destroy]

  def index
    @events = Event.order(occurred_on: :desc)
  end

  def new
    @event = Event.new(occurred_on: Date.current)
  end

  def edit; end

  def create
    @event = Event.new(event_params)
    if @event.save
      redirect_to admin_events_path, notice: "Event added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @event.update(event_params)
      redirect_to admin_events_path, notice: "Event updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to admin_events_path, notice: "Event removed."
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :description, :occurred_on, :kind)
  end
end
