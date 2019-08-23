require_relative './command'

class DockerCommands
  def self.kill_all
    puts "Stopping all docker containers..."
    containers = Command.new("docker", "ps", "-q").run!.raise!
    containers.stdout.each do |container|
      puts "\tStopping #{container.chomp}..."
      Command.new("docker", "kill", container.chomp).run!
    end
  end

  def self.run_rust_tests(context)
    compose_flags = ["--file", "#{context.server_root_path}/.buildkite/build-cli/docker-test-setups/docker-compose.test.all.yml"]
    Command.new("docker-compose", *compose_flags, "up", "-d", "test-db-postgres", "test-db-mysql").puts!.run!.raise!

    sleep(10)

    puts "Starting tests for ..."
    test_run = Command.new("docker-compose", *compose_flags, "run", "rust", "./test.sh").puts!.run!.raise!

    puts "Stopping services..."
    cleanup = Command.new("docker-compose", *compose_flags, "down", "-v", "--remove-orphans").puts!.run!.raise!
  end

  def self.run_connector_test_kit(context, connector)
    compose_flags = ["--file", "#{context.server_root_path}/.buildkite/build-cli/docker-test-setups/docker-compose.test.all.yml"]
    Command.new("docker-compose", *compose_flags, "up", "-d", "test-db-postgres", "test-db-mysql").puts!.run!.raise!

    sleep(10)

    puts "Starting tests for #{connector}..."
    test_run = Command.new("docker-compose", *compose_flags, "run", "rust", "./test_connector.sh", connector).puts!.run!.raise!

    puts "Stopping services..."
    cleanup = Command.new("docker-compose", *compose_flags, "down", "-v", "--remove-orphans").puts!.run!.raise!
  end

  def self.native_image(context, prisma_version, build_image)
    Command.new("docker", "run",
      "-e", "SERVER_ROOT=/root/build",
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      "-e", "BRANCH=#{context.branch}",
      "-e", "COMMIT_SHA=#{context.commit}",
      "-e", "CLUSTER_VERSION=#{prisma_version}",
      '-w', '/root/build',
      '-v', "#{context.server_root_path}:/root/build",
      '-v', "#{File.expand_path('~')}/.ivy2:/root/.ivy2",
      '-v', "#{File.expand_path('~')}/.coursier:/root/.coursier",
      '-v', '/var/run/docker.sock:/var/run/docker.sock',
      "prismagraphql/#{build_image}",
      'sbt', 'project prisma-native', "prisma-native-image:packageBin").puts!.run!.raise!
  end

  def self.rust_binary_musl(context)
    Command.new("docker", "run",
      '-w', '/root/build',
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      '-e', 'CC=gcc',
      '-v', "#{context.server_root_path}:/root/build",
      'prismagraphql/build-image:alpine',
      'cargo', 'build', "--target=x86_64-unknown-linux-musl", "--release").puts!.run!.raise!
  end

  def self.rust_binary_zeit(context)
    Command.new("docker", "run",
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      '-w', '/root/build',
      '-v', "#{context.server_root_path}:/root/build",
      'prismagraphql/build-image:centos6-0.5',
      'cargo', 'build', "--release").puts!.run!.raise!
  end

  def self.rust_binary_lambda(context)
    Command.new("docker", "run",
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      '-w', '/root/build',
      '-v', "#{context.server_root_path}:/root/build",
      'prismagraphql/build-image:lambda-1.1',
      'cargo', 'build', "--release").puts!.run!.raise!
  end

  def self.rust_binary(context)
    Command.new("docker", "run",
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      '-w', '/root/build',
      '-v', "#{context.server_root_path}:/root/build",
      '-v', '/var/run/docker.sock:/var/run/docker.sock',
      '-v', "#{File.expand_path('~')}/cargo_cache:/root/cargo_cache",
      "prismagraphql/build-image:debian",
      'cargo', 'build', "--release").puts!.run!.raise!
  end

  def self.rust_binary_windows(context)
    Command.new("docker", "run",
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      '-w', '/root/build',
      '-v', "#{context.server_root_path}:/root/build",
      '-v', '/var/run/docker.sock:/var/run/docker.sock',
      '-v', "#{File.expand_path('~')}/cargo_cache:/root/cargo_cache",
      "prismagraphql/build-image:debian",
      'cargo', 'build', "--release", "--target", "x86_64-pc-windows-gnu").puts!.run!.raise!
  end
end
