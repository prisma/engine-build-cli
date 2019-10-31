class PipelineStep
  def initialize
    @label = ""
    @command = ""
    @queue = nil
    @branches = []
    @wait = false
    @block = false
  end

  def wait!
    @wait = true
    self
  end

  def trigger!(pipeline)
    @trigger = pipeline
    self
  end

  def block!(label)
    @label = label
    @block = true
    self
  end

  def label(l)
    @label = l
    self
  end

  def command(c)
    @command = c
    self
  end

  def queue(q)
    @queue = q
    self
  end

  def branches(b)
    @branches = [*b]
    self
  end

  def render!(indent = 2)
    if @wait
      return " " * indent + "- wait"
    end

    if @block
      return " " * indent + "- block: \"#{@label}\""
    end

    if @trigger
      rendered = [
        "- trigger: \"#{@trigger}\"",
        "  label: \"#{@label}\""
      ]

      unless @branches.empty?
        rendered.push "  branches: #{@branches.join(' ')}"
      end
    else
      rendered = [
        "- label: \"#{@label}\"",
        "  command: #{@command}"
      ]

      unless @branches.empty?
        rendered.push "  branches: #{@branches.join(' ')}"
      end

      unless @queue.nil?
        rendered += [
          "  agents:",
          "    queue: #{@queue}"
        ]
      end
    end

    rendered.map { |render| " " * indent + render }.join("\n")
  end
end