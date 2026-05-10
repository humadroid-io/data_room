class DataRoomChannel < ApplicationCable::Channel
  def subscribed
    stream_from "data_room"
  end
end
