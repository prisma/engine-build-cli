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
    compose_flags = ["--file", "#{context.server_root_path}/.buildkite/engine-build-cli/docker-test-setups/docker-compose.test.all.yml"]
    Command.new("docker-compose", *compose_flags, "up", "-d", "test-db-postgres", "test-db-mysql-5-7", "test-db-mysql-8-0").puts!.run!.raise!

    sleep(10)

    puts "Starting tests for ..."
    test_run = Command.new("docker-compose", *compose_flags, "run", "rust", "./test.sh").puts!.run!.raise!

    puts "Stopping services..."
    cleanup = Command.new("docker-compose", *compose_flags, "down", "-v", "--remove-orphans").puts!.run!.raise!
  end

  def self.run_connector_test_kit(context, connector)
    compose_flags = ["--file", "#{context.server_root_path}/.buildkite/engine-build-cli/docker-test-setups/docker-compose.test.all.yml"]
    Command.new("docker-compose", *compose_flags, "up", "-d", "test-db-postgres", "test-db-mysql-5-7").puts!.run!.raise!

    sleep(10)

    puts "Starting tests for #{connector}..."
    test_run = Command.new("docker-compose", *compose_flags, "run", "rust", "./test_connector.sh", connector).puts!.run!.raise!

    puts "Stopping services..."
    cleanup = Command.new("docker-compose", *compose_flags, "down", "-v", "--remove-orphans").puts!.run!.raise!
  end

  def self.rust_binary(context)
    Command.new("docker", "run",
      '-w', '/root/build',
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      "-e", "CARGO_TARGET_DIR=/root/cargo-cache",
      '-v', "#{context.server_root_path}:/root/build",
      '-v', "#{context.cargo_target_base_dir}/debian:/root/cargo-cache",
      '-v', '/var/run/docker.sock:/var/run/docker.sock',
      "prismagraphql/build-image:debian",
      'cargo', 'build', "--release").puts!.run!.raise!
  end

  def self.rust_binary_musl(context)
    Command.new("docker", "run",
      '-w', '/root/build',
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      '-e', 'CC=gcc',
      "-e", "CARGO_TARGET_DIR=/root/cargo-cache",
      '-v', "#{context.cargo_target_base_dir}/musl:/root/cargo-cache",
      '-v', "#{context.server_root_path}:/root/build",
      'prismagraphql/build-image:alpine',
      'cargo', 'build', "--target=x86_64-unknown-linux-musl", "--release").puts!.run!.raise!
  end

  def self.rust_binary_zeit(context)
    Command.new("docker", "run",
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      '-w', '/root/build',
      "-e", "CARGO_TARGET_DIR=/root/cargo-cache",
      '-v', "#{context.server_root_path}:/root/build",
      '-v', "#{context.cargo_target_base_dir}/centos:/root/cargo-cache",
      'prismagraphql/build-image:centos6-0.5',
      'cargo', 'build', "--release").puts!.run!.raise!
  end

  def self.rust_binary_lambda(context)
    Command.new("docker", "run",
      '-w', '/root/build',
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      "-e", "CARGO_TARGET_DIR=/root/cargo-cache",
      '-v', "#{context.server_root_path}:/root/build",
      '-v', "#{context.cargo_target_base_dir}/lambda:/root/cargo-cache",
      'prismagraphql/build-image:lambda-1.1',
      'cargo', 'build', "--release").puts!.run!.raise!
  end

  def self.rust_binary_windows(context)
    Command.new("docker", "run",
      '-w', '/root/build',
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      "-e", "CARGO_TARGET_DIR=/root/cargo-cache",
      '-v', "#{context.server_root_path}:/root/build",
      '-v', "#{context.cargo_target_base_dir}/windows:/root/cargo-cache",
      '-v', '/var/run/docker.sock:/var/run/docker.sock',
      "prismagraphql/build-image:debian",
      'cargo', 'build', "--release", "--target", "x86_64-pc-windows-gnu").puts!.run!.raise!
  end

  def self.rust_binary_ubuntu16(context)
    Command.new("docker", "run",
      '-w', '/root/build',
      "-e", "SQLITE_MAX_VARIABLE_NUMBER=250000",
      "-e", "SQLITE_MAX_EXPR_DEPTH=10000",
      "-e", "CARGO_TARGET_DIR=/root/cargo-cache",
      '-v', "#{context.server_root_path}:/root/build",
      '-v', "#{context.cargo_target_base_dir}/ubuntu:/root/cargo-cache",
      '-v', '/var/run/docker.sock:/var/run/docker.sock',
      "prismagraphql/build-image:ubuntu16.04",
      'cargo', 'build', "--release").puts!.run!.raise!
  end
end
