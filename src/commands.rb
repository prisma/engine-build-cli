require_relative './pipeline_renderer'
require_relative './command'
require_relative './docker'

def upload_pipeline(context)
  yml = PipelineRenderer.new(context).render!
  res = Command.new("buildkite-agent", "pipeline", "upload").with_stdin([yml]).run!.raise!

  if res.success?
    puts "Successfully uploaded pipeline"
  end
end

def test_rust(context)
  DockerCommands.kill_all
  DockerCommands.run_rust_tests(context)
end

def connector_test_kit(context, connector)
  DockerCommands.kill_all
  DockerCommands.run_connector_test_kit(context, connector)
end

def rust_binary(context, platform)
  # Artifact whitelist. All named will be zipped and uploaded
  upload_artifacts = ["prisma", "migration-engine", "prisma-fmt"]

  # Upload folder paths in s3
  artifact_paths = []

  if platform == "alpine"
    artifact_paths.push(artifact_paths_for(context, "linux-musl-libssl1.1.0"))
    DockerCommands.rust_binary_musl(context)
    Dir.chdir("#{context.server_root_path}/prisma-rs/target/x86_64-unknown-linux-musl/release") # Necessary to keep the buildkite agent from prefixing the binary when uploading

  elsif platform == "debian"
    artifact_paths.push(artifact_paths_for(context, "linux-glibc-libssl1.1.0"))
    DockerCommands.rust_binary(context)
    Dir.chdir("#{context.server_root_path}/prisma-rs/target/release") # Necessary to keep the buildkite agent from prefixing the binary when uploading

  elsif platform == "zeit"
    artifact_paths.push(artifact_paths_for(context, "linux-glibc-libssl1.0.1"))
    DockerCommands.rust_binary_zeit(context)
    Dir.chdir("#{context.server_root_path}/prisma-rs/target/release") # Necessary to keep the buildkite agent from prefixing the binary when uploading

  elsif platform == "lambda"
    artifact_paths.push(artifact_paths_for(context, "linux-glibc-libssl1.0.2"))
    DockerCommands.rust_binary_lambda(context)
    Dir.chdir("#{context.server_root_path}/prisma-rs/target/release") # Necessary to keep the buildkite agent from prefixing the binary when uploading

  elsif platform == "native"
    artifact_paths.push(artifact_paths_for(context, "darwin"))
    puts "Updating rust..."
    Command.new("rustup", "update").puts!.run!.raise!

    puts "Cleaning up..."
    Command.new("cargo", "clean", "--manifest-path=#{context.server_root_path}/prisma-rs/Cargo.toml").puts!.run!.raise!

    puts "Building..."
    Command.new("cargo", "build", "--manifest-path=#{context.server_root_path}/prisma-rs/Cargo.toml", "--release").puts!.run!.raise!
    Dir.chdir("#{context.server_root_path}/prisma-rs/target/release") # Necessary to keep the buildkite agent from prefixing the binary when uploading

  elsif platform == "windows"
    artifact_paths.push(artifact_paths_for(context, "windows"))
    DockerCommands.rust_binary_windows(context)
    Dir.chdir("#{context.server_root_path}/prisma-rs/target/x86_64-pc-windows-gnu/release") # Necessary to keep the buildkite agent from prefixing the binary when uploading
    upload_artifacts = ["prisma.exe", "migration-engine.exe", "prisma-fmt.exe"]
  else
    raise "Unsupported platform #{platform}"
  end

  # Gzip all artifacts
  upload_artifacts.each do |upload_artifact|
    Command.new('gzip', '-f', upload_artifact).puts!.run!.raise!
  end

  artifact_paths.flatten.each do |path|
    upload_artifacts.each do |upload_artifact|
      Command.new("buildkite-agent", "artifact", "upload", "#{upload_artifact}.gz").with_env({
        "BUILDKITE_S3_DEFAULT_REGION" => "eu-west-1",
        "BUILDKITE_ARTIFACT_UPLOAD_DESTINATION" => path
      }).puts!.run!.raise!
    end
  end
end

# Builds s3 folder path based on context.
def artifact_paths_for(context, target_name)
  artifact_s3_paths = ["s3://#{ENV["RUST_ARTIFACT_BUCKET"]}/#{context.branch}/#{context.commit}/#{target_name}"]

  if context.branch == "alpha" || context.branch == "beta" || (!context.tag.nil? && (context.tag.stable? || context.tag.beta?))
    artifact_s3_paths.push "s3://#{ENV["RUST_ARTIFACT_BUCKET"]}/#{context.branch}/latest/#{target_name}"
  end

  artifact_s3_paths
end

# def trigger_dependent_pipeline(channel, tags)
#   pipeline_input = <<~EOS
#     - trigger: \"prisma-cloud\"
#       label: \":cloud: Trigger Prisma Cloud Tasks #{tags.join(", ")} :cloud:\"
#       async: true
#       build:
#         env:
#             BUILD_TAGS: \"#{tags.join(',')}\"
#             CHANNEL: \"#{channel}\"
#   EOS

#   res = Command.new("buildkite-agent", "pipeline", "upload").with_stdin([pipeline_input]).run!.raise!
# end

# Eliminates consistency issues on buildkite
def git_fetch
  Command.new("git", "fetch", "--tags", "-f").run!.raise!
end