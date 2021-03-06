require 'spec_helper'

describe Leaderboard, :create do
  it "creates a new leaderboard" do
    game = FactoryGirl.build(:game, {:name => 'spice finder'})
    leaderboard = Leaderboard.create('into the sand', -3, LeaderboardType::LowToHigh, LeaderboardMode::Normal, game)
    leaderboard.name.should == 'into the sand'
    leaderboard.offset.should == -3
    leaderboard.type.should == LeaderboardType::LowToHigh
    leaderboard.game_id.should == game.id
    leaderboard.mode.should == LeaderboardMode::Normal
  end
end