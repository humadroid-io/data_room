# Lexxy's exporter writes strikethrough as <s> and underline as <u>
# (see lexxy.esm.js: exportTextNodeDOM), but Lexxy's own sanitization
# initializer does NOT include those tags in the allow-list. Result:
# ActionText::Content.to_s strips them at render time, leaving plain
# text inside its parent <p>. Add them back here.
#
# Also allow <figure>/<figcaption> (Lexxy uses them for image attachments
# and table wrappers) and <thead> for full table support.

ActiveSupport.on_load(:action_text_content) do
  extras = %w[u s strike figure figcaption thead]

  current = ActionText::ContentHelper.allowed_tags
  if current.nil?
    # Lexxy's hook hasn't replaced the lazy default yet — derive from the
    # raw sanitizer allow-list ourselves so the += below has something
    # to extend. Lexxy will then re-extend it when its own hook fires.
    current = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_tags
  end

  ActionText::ContentHelper.allowed_tags = current + extras
end
