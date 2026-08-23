$imported ||= {}
$imported['cyanic-SteamUserStatsLite'] = 7 # keep the same version flag other scripts may check

class SteamUserStatsLite
  def initialize
    @initted = false
  end

  def shutdown
  end

  def initted?
    false
  end

  def self.restart_app_if_necessary(app_id)
    false
  end

  def update
  end

  def is_subscribed
    nil
  end

  def is_dlc_installed(app_id)
    nil
  end

  def request_current_stats
    false
  end

  def get_stat_int(name)
    nil
  end

  def get_stat_float(name)
    nil
  end

  def set_stat(name, val)
    false
  end

  def update_avg_rate_stat(name, count_this_session, session_length)
    false
  end

  def get_achievement(name)
    nil
  end

  def set_achievement(name)
    false
  end

  def clear_achievement(name)
    false
  end

  def get_achievement_and_unlock_time(name)
    nil
  end

  def get_achievement_display_attribute(name, key)
    nil
  end

  def indicate_achievement_progress(name, cur_progress, max_progress)
    false
  end

  def get_num_achievements
    nil
  end

  def get_achievement_name(achievement)
    nil
  end

  def reset_all_stats(achievements_too)
    false
  end

  def self.instance
    @@instance
  end

  @@instance = self.new
end
