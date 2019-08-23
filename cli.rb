require_relative './src/build_context'
require_relative './src/command'
require_relative './src/commands'

git_fetch
context = BuildContext.new

def print_usage
  puts """Prisma RS Build Tool
Usage: cli <subcommand>

Subcommands:
\tpipeline
\t\tRenders the pipeline based on the current build context and uploads it to buildkite.

\trust-binary <platform>
\t\tCompiles the Prisma Rust binary on the current platform on the current CI branch. Artifacts are always published to S3.
\t\t<platform>: native (bare on the machine without docker), debian, alpine

\ttest-rust
\t\truns the tests for prisma-rs

\tconnector-test <connector>
\t\tTests the given connector against the connector test kit.
"""
end

if ARGV.length <= 0
  print_usage
  exit 1
end

command = ARGV[0]

case command
when "pipeline"
  upload_pipeline(context)

when "rust-binary"
  if ARGV.length < 2
    print_usage
    exit 1
  end

  rust_binary(context, ARGV[1])

when "test-rust"
  test_rust(context)

when "connector-test"
  connector = ARGV[1]
  connector_test_kit(context, connector)

else
  puts "Invalid command: #{command}"
  exit 1
end