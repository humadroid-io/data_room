require "test_helper"

class PageRedirectTest < ActiveSupport::TestCase
  subject { build(:page_redirect) }

  should belong_to(:page)
  should validate_presence_of(:old_path)
  should validate_uniqueness_of(:old_path)
end
