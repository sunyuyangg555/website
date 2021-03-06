require 'test_helper'

class PauseUserTrackTest < ActiveSupport::TestCase
  test "pauses user track" do
    user_track = create :user_track
    exercise = create :exercise, track: user_track.track
    solution = create :solution, exercise: exercise, user: user_track.user
    create :iteration, solution: solution

    PauseUserTrack.(user_track)

    assert user_track.reload.paused?
    assert solution.reload.paused?
  end
end
