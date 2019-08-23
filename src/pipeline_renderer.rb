require_relative './pipeline_step'

class PipelineRenderer
  @@wait_step = PipelineStep.new.wait!

  def block_step
    if ["alpha", "beta", "master"].include?(@context.branch) || (!@context.tag.nil? && (@context.tag.beta? || @context.tag.stable?))
      # In case we're on one of the channels, always publish (just wait for previous steps to finish)
      @@wait_step
    else
      PipelineStep.new.block!(":rocket: Publish binaries")
    end
  end

  def initialize(context)
    @context = context
  end

  def render!
    steps = collect_steps
    rendered = <<~EOS
      steps:
      #{steps.compact.map { |step| step.render!(2) }.join "\n\n"}
    EOS

    puts rendered
    rendered
  end

  def collect_steps
    [ rust_tests,
      block_step,
      release_rust_artifacts
    ].flatten
  end

  def rust_tests
      [
        PipelineStep.new
          .label(":rust: Cargo test prisma-rs")
          .command("./server/.buildkite/pipeline.sh test-rust"),

        PipelineStep.new
          .label(":sqlite: connector-test-kit sqlite")
          .command("./server/.buildkite/pipeline.sh connector-test sqlite"),

        PipelineStep.new
          .label(":postgres: connector-test-kit postgres")
          .command("./server/.buildkite/pipeline.sh connector-test postgres"),

        PipelineStep.new
          .label(":mysql: connector-test-kit mysql")
          .command("./server/.buildkite/pipeline.sh connector-test mysql")
      ]
  end

  def release_rust_artifacts
    [
      PipelineStep.new
        .label(":rust: Build & Publish :linux: glibc")
        .command("./server/.buildkite/pipeline.sh rust-binary debian"),

      PipelineStep.new
        .label(":rust: Build & Publish :linux: musl")
        .command("./server/.buildkite/pipeline.sh rust-binary alpine"),

      PipelineStep.new
        .label(":rust: Build & Publish :linux: zeit now")
        .command("./server/.buildkite/pipeline.sh rust-binary zeit"),

      PipelineStep.new
        .label(":rust: Build & Publish :linux: :lambda: lambda")
        .command("./server/.buildkite/pipeline.sh rust-binary lambda"),

      PipelineStep.new
        .label(":rust: Build & Publish :darwin:")
        .command("./server/.buildkite/pipeline.sh rust-binary native")
        .queue("macos"),

      PipelineStep.new
        .label(":rust: Build & Publish :windows:")
        .command("./server/.buildkite/pipeline.sh rust-binary windows")
    ]
  end
end
