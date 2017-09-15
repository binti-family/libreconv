require "libreconv/version"
require "uri"
require "net/http"
require "tmpdir"
require "posix-spawn"

module Libreconv

  def self.convert(source, target, soffice_command: nil, convert_to: nil, timeout: 15)
    Converter.new(source, target, soffice_command: soffice_command, convert_to: convert_to, timeout: timeout).convert
  end

  class Converter
    attr_accessor :soffice_command

    def initialize(source, target, soffice_command: nil, convert_to: nil, timeout: 15)
      @source = source
      @target = target
      @soffice_command = soffice_command
      @convert_to = convert_to || "pdf"
      @timeout = timeout
      determine_soffice_command
      check_source_type

      unless @soffice_command && File.exists?(@soffice_command)
        raise IOError, "Can't find Libreoffice or Openoffice executable."
      end
    end

    def convert
      Dir.mktmpdir { |target_path|
        child = POSIX::Spawn::Child.build(@soffice_command, "--headless", "--convert-to", @convert_to, @source, "--outdir", target_path, timeout: @timeout)
        child.exec!
        target_tmp_file = "#{target_path}/#{File.basename(@source, ".*")}.#{File.basename(@convert_to, ":*")}"
        FileUtils.cp target_tmp_file, @target
      }
    end

    private

    def determine_soffice_command
      unless @soffice_command
        @soffice_command ||= which("soffice")
        @soffice_command ||= which("soffice.bin")
      end
    end

    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable? exe
        end
      end

      return nil
    end

    def check_source_type
      return if File.exists?(@source) && !File.directory?(@source) #file
      return if URI(@source).scheme == "http" && Net::HTTP.get_response(URI(@source)).is_a?(Net::HTTPSuccess) #http
      return if URI(@source).scheme == "https" && Net::HTTP.get_response(URI(@source)).is_a?(Net::HTTPSuccess) #https
      raise IOError, "Source (#{@source}) is neither a file nor an URL."
    end
  end
end
