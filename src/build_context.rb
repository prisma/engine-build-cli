require 'rbconfig'
require 'pathname'
require 'uri'
require 'net/http'
require 'json'
require_relative './command'

class BuildContext
  attr_accessor :branch, :tag, :commit, :last_git_tag, :server_root_path, :cargo_target_base_dir

  def initialize
    @branch = ENV["BUILDKITE_BRANCH"] || nil
    @tag = (ENV["BUILDKITE_TAG"].nil? || ENV["BUILDKITE_TAG"].empty?) ? nil : Tag.new(ENV["BUILDKITE_TAG"])
    @commit = ENV["BUILDKITE_COMMIT"] || nil
    @last_git_tag = get_last_git_tag
    @server_root_path = find_server_root

    begin
      @cargo_target_base_dir = "#{File.expand_path('~')}/cargo-cache"
    rescue
      @cargo_target_base_dir = "/cargo-cache"
    end
  end

  def get_last_git_tag
    last_tags = Command.new("git", "tag", "--sort=-version:refname").run!.raise!
    filtered = last_tags.get_stdout.lines.map(&:chomp).select { |tag| !tag.empty? && !tag.include?("beta") && !tag.start_with?("v") }
    Tag.new(filtered.first)
  end

  def cli_invocation_path
    "#{server_root_path}/.buildkite/pipeline.sh"
  end

  def is_windows?
    os == :windows
  end

  def is_nix?
    os == :macosx || os == :unix || os == :linux
  end

  def buildkite_build?
    @branch != "local"
  end

  def connectors
    [:postgres, :mysql, :sqlite, :mongo36, :mongo40]
  end

  def native_image_targets
    [:debian, :lambda]
  end

  def os
    @os ||= (
      host_os = RbConfig::CONFIG['host_os']
      case host_os
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        :windows
      when /darwin|mac os/
        :macosx
      when /linux/
        :linux
      when /solaris|bsd/
        :unix
      else
        raise "Unknown host system: #{host_os.inspect}"
      end
    )
  end

  # We assume that we always run in the server root already (see cli.rb chdir)
  def find_server_root
    Pathname.new(Dir.pwd)
  end
end

class Tag
  attr_accessor :major, :minor, :patch, :channel, :revision

  def initialize(tag)
    unless tag.nil? || !tag.include?(".")
      chunked = tag.split("-")
      raw_version = chunked[0]

      if chunked.length >= 2
        @channel = chunked[1]
      end

      if chunked.length == 3
        @revision = chunked[2].to_i
      end

      @major, @minor, @patch = raw_version.split(".").map { |x| x.to_i }
    end
  end

  def nil?
    @major.nil? || @minor.nil?
  end

  def beta?
    !nil? && @channel == "beta"
  end

  def stable?
    !nil? && @channel.nil?
  end

  def stringify
    if nil?
      ""
    else
      stringified = "#{@major}.#{@minor}#{@patch.nil? ? "" : ".#{@patch}"}"
      unless @channel.nil?
        stringified += "-#{@channel}"
      end

      unless @revision.nil?
        stringified += "-#{@revision}"
      end

      stringified
    end
  end
end
