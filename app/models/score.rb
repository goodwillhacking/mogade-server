class Score
  include MongoLight::Document
  attr_accessor :leaderboard
  mongo_accessor({:leaderboard_id => :lid, :unique => :u, :userkey => :uk, :username => :un,
    :daily => {:field => :d, :class => ScoreData},
    :weekly => {:field => :w, :class => ScoreData},
    :overall => {:field => :o, :class => ScoreData}})

  @@prefixes = {LeaderboardScope::Daily => 'd', LeaderboardScope::Weekly => 'w', LeaderboardScope::Overall => 'o'}

  class << self
    def load(leaderboard, player)
      score = find_one({:leaderboard_id => leaderboard.id, :unique => player.unique})
      if score.nil?
        score = Score.new({:leaderboard_id => leaderboard.id, :unique => player.unique, :userkey => player.userkey, :username => player.username, :daily => ScoreData.blank, :weekly => ScoreData.blank, :overall => ScoreData.blank})
      else
        score.scrub!(leaderboard)
      end
      score.leaderboard = leaderboard
      score
    end

    def save(leaderboard, player, points, data = nil, attempt = 1)
      data = data[0..49] unless data.nil? || data.length < 50

      score = Score.load(leaderboard, player)
      now = Time.now.utc
      changed = {}

      changed[LeaderboardScope::Daily] = score.update_if_better(LeaderboardScope::Daily, points, data, now)
      changed[LeaderboardScope::Weekly] = score.update_if_better(LeaderboardScope::Weekly, points, data, now)
      changed[LeaderboardScope::Overall] = score.update_if_better(LeaderboardScope::Overall, points, data, now)

      if changed.has_value?(true)
        begin
          score.save! unless score.overall == 0
        rescue Mongo::OperationFailure
          if attempt == 1 && $!.duplicate?
            save(leaderboard, player, points, data, 2)
          else
            raise
          end
        end
      end
      ScoreDaily.save(leaderboard, player, points, data) if changed[LeaderboardScope::Daily]
      changed
    end

    def get_by_page(leaderboard, page, records, scope)
      records = 50 if records > 50
      offset = ((page-1) * records).floor
      offset = 0 if offset < 0

      if scope == LeaderboardScope::Yesterday
        return { :page => page, :scores => ScoreDaily.get_by_stamp_and_page(leaderboard, leaderboard.yesterday_stamp, records, offset)}
      end

      prefix = Score.scope_to_prefix(scope)
      name = Score.scope_to_name(scope)
      conditions = Score.time_condition(leaderboard, scope)
      conditions[:leaderboard_id] = leaderboard.id
      options = {:fields => {prefix + '.p' => true, :username => true, prefix + '.d' => true, prefix + '.dt' => true, :_id => false}, :sort => [prefix + '.p', leaderboard.sort], :skip => offset, :limit => records, :raw => true}

      found = find(conditions, options).map{|s| {:username => s[:username], :points => s[name][:points], :data => s[name][:data], :dated => s[name][:dated]}}
      fix_names(found) if leaderboard.id.to_s == '4e657c876d574806b1000002'
      {:page => page,  :scores => found}
    end

    def fix_names(scores)
      scores.each do |s|
        s[:username] = s[:username].scan(/[A-z0-9]/).join()
        s[:username] = '????' if s[:username].blank?
      end
    end

    def get_by_player(leaderboard, player, records, scope)
      records = 50 if records > 50
      rank = Rank.get_for_player(leaderboard, player.unique, scope)
      page = rank == 0 ? 1 : (rank / records.to_f).ceil
      get_by_page(leaderboard, page, records, scope)
    end

    def find_for_player(game, player)
      leaderboards = Leaderboard.find({:game_id => game.id})
      leaderboards.map{|leaderboard| Score.load(leaderboard, player)}
    end

    def get_rivals(leaderboard, player, scope)
      score = Score.load(leaderboard, player).for_scope(scope)
      return unless score.dated

      prefix = Score.scope_to_prefix(scope)
      name = Score.scope_to_name(scope)
      conditions = Score.time_condition(leaderboard, scope)
      conditions[:leaderboard_id] = leaderboard.id
      conditions[prefix + '.p'] = {leaderboard.score_comparer => score.points}
      options = {:fields => {prefix + '.p' => 1, :username => 1, prefix + '.d' => 1, prefix + '.dt' => 1, :_id => 0}, :sort => [prefix + '.p', leaderboard.inverse_sort], :limit => 3, :raw => true}

      #p conditions
      find(conditions, options).map{|s| {:username => s[:username], :points => s[name][:points], :data => s[name][:data], :dated => s[name][:dated]}}
    end

    def scope_to_prefix(scope)
      @@prefixes[scope]
    end
    def scope_to_name(scope)
      case scope
      when LeaderboardScope::Weekly
        return :weekly
      when LeaderboardScope::Overall
        return :overall
      else
        return :daily
      end
    end

    def time_condition(leaderboard, scope)
      case scope
      when LeaderboardScope::Overall
        return {'o' => {'$exists' => true}}
      when LeaderboardScope::Weekly
        return {'w.s' => leaderboard.weekly_stamp}
      else
        return {'d.s' => leaderboard.daily_stamp}
      end
    end

    def daily_collection
      Store['scores_daily']
    end
  end

  def for_scope(scope)
    case scope
    when LeaderboardScope::Overall
      return overall
    when LeaderboardScope::Weekly
      return weekly
    else
      return daily
    end
  end

  def scrub!(leaderboard)
    self.daily = ScoreData.blank if daily.nil?
    self.daily.points = 0 if daily.stamp.nil? || daily.stamp < leaderboard.daily_stamp
    self.weekly = ScoreData.blank if weekly.nil?
    self.weekly.points = 0 if weekly.stamp.nil? || weekly.stamp < leaderboard.weekly_stamp
    self.overall = ScoreData.blank if overall.nil?
    self.overall.points = 0 if overall.points.nil?
    self
  end

  def update_if_better(scope, points, data, date)
    name = Score.scope_to_name(scope)
    score_data = send(name)
    return false unless @leaderboard.score_is_better?(points, score_data.points, scope)

    Rank.save(@leaderboard, scope, unique, points)
    score_data.points = points
    score_data.data = data
    score_data.dated = date
    score_data.stamp = @leaderboard.send("#{name}_stamp") if @leaderboard.respond_to?("#{name}_stamp")
    true
  end
end