module GitAPI
  class ConceptExercisesController < BaseController
    def create
      # Validate presence and size of fields
      %i{ 
        track_slug exercise_slug example_filename example_code
        design_markdown instructions_markdown
      }.each do |param|
        return render_error(:"missing_#{param}") unless params[param].present?
        return render_error(:"too_large_#{param}") if params[param].size > 1.megabyte
      end

      # Validate regexps
      return render_error(:invalid_exercise_slug) if params[:exercise_slug] =~ Regexp.new("[^a-zA-Z0-9-]")
      return render_error(:invalid_example_filename) if params[:example_filename] =~ Regexp.new("[^a-zA-Z0-9._-]")

      # Get the track and get out of here if it doesn't exist
      track = Track.find_by_slug(params[:track_slug])
      return render_error(:track_not_found) unless track

      uuid = SecureRandom.uuid.gsub('-', '')
      tmp_path = Pathname.new("/tmp/#{uuid}")
      branch_name = "#{params[:track_slug]}/#{params[:exercise_slug]}-#{uuid}"

      `git clone https://#{Rails.application.secrets.exercism_bot_credentials}@github.com/exercism-bot/v3.git #{tmp_path}`

      Dir.chdir(tmp_path) do
        `git remote add upstream https://github.com/exercism/v3.git`
        `git fetch upstream master`
        `git checkout --no-track -b #{branch_name} upstream/master`
      end

      File.open(tmp_path / "instructions.md", "w") {|f|f.write params[:instructions_markdown] }
      File.open(tmp_path / "design.md", "w") {|f|f.write params[:design_markdown] }
      File.open(tmp_path / params[:example_filename], "w") {|f|f.write params[:example_code] }

      Dir.chdir(tmp_path) do
        `git add .`
        `git config user.name #{current_user.name}`
        `git config user.email #{current_user.email}`
        `git commit -m "[#{track.title}] Add #{params[:exercise_slug]} Concept Exercise"`
        `git push origin #{branch_name}`
      end

      render json: {
        branch_name: branch_name
      }, status: 201
    end

    def render_error(type)
      p "Error: #{type}"
      render json: {
        error: { type: type }
      }, status: 400
    end
  end
end
