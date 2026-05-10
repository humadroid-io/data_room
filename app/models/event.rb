class Event < ApplicationRecord
  KINDS = {
    funding:     0,
    launch:      1,
    hire:        2,
    partnership: 3,
    milestone:   4,
    risk:        5,
    other:       6
  }.freeze

  COLORS = {
    "funding"     => "#16a34a",  # green
    "launch"      => "#2563eb",  # blue
    "hire"        => "#7c3aed",  # purple
    "partnership" => "#0891b2",  # cyan
    "milestone"   => "#ea580c",  # orange
    "risk"        => "#dc2626",  # red
    "other"       => "#525252"   # gray
  }.freeze

  enum :kind, KINDS, prefix: true, default: :other

  validates :title, presence: true
  validates :occurred_on, presence: true

  scope :chronological, -> { order(:occurred_on) }
  scope :in_period, ->(from, to) {
    rel = all
    rel = rel.where(occurred_on: from..) if from
    rel = rel.where(occurred_on: ..to)   if to
    rel
  }

  def color
    COLORS[kind]
  end

  def month_bucket
    occurred_on.strftime("%Y-%m")
  end
end
