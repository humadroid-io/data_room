require "test_helper"

class PageViewTest < ActiveSupport::TestCase
  should belong_to(:investor)
  should belong_to(:page)
  should validate_presence_of(:viewed_at)
end
