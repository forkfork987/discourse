# frozen_string_literal: true

class WebHookEventsDailyAggregate < ActiveRecord::Base
  belongs_to :web_hook

  default_scope { order("created_at DESC") }
  after_create :aggregate

  def self.purge_old
    where("created_at < ?", SiteSetting.retain_web_hook_events_period_days.days.ago).delete_all
  end

  def self.by_day(start_date, end_date, web_hook_id = nil)
    result = where("date >= ? AND date <= ?", start_date.to_date, end_date.to_date)
    result = result.where(web_hook_id: web_hook_id) if web_hook_id
    result
  end

  def aggregate
    events =
      WebHookEvent.where(
        "created_at >= ? AND created_at < ? AND web_hook_id = ?",
        self.date,
        self.date + 1.day,
        self.web_hook_id,
      )

    self.mean_duration = events.sum(:duration) / events.count if events.count > 0

    self.successful_events_id = events.where("status >= 200 AND status <= 299").pluck(:id)
    self.failed_events_id = events.where("status < 200 OR status > 299").pluck(:id)

    self.save!
  end
end

# == Schema Information
#
# Table name: web_hook_events_daily_aggregates
#
#  id                   :bigint           not null, primary key
#  web_hook_id          :bigint           not null
#  date                 :date
#  successful_events_id :integer          is an Array
#  failed_events_id     :integer          is an Array
#  mean_duration        :integer          default(0)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_web_hook_events_daily_aggregates_on_web_hook_id  (web_hook_id)
#
