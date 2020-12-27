module FakeFS
  # FakeFs Dir class
  class Dir
    include Enumerable
    attr_reader :path

    def self._check_for_valid_file(path)
      fail Errno::ENOENT, path unless FileSystem.find(path)
    end

    def initialize(string)
      self.class._check_for_valid_file(string)

      @path = FileSystem.normalize_path(string)
      @open = true
      @pointer = 0
      @contents = ['.', '..'] + FileSystem.find(@path).entries
    end

    def close
      @open = false
      @pointer = nil
      @contents = nil
      nil
    end

    def each(&_block)
      while (f = read)
        yield f
      end
    end

    def pos
      @pointer
    end

    def pos=(integer)
      @pointer = integer
    end

    def read
      fail IOError, 'closed directory' if @pointer.nil?
      n = @contents[@pointer]
      @pointer += 1
      return unless n

      if n.to_s[0, path.size + 1] == path + '/'
        n.to_s[path.size + 1..-1]
      else
        n.to_s
      end
    end

    def rewind
      @pointer = 0
    end

    def seek(integer)
      fail IOError, 'closed directory' if @pointer.nil?
      @pointer = integer
      @contents[integer]
    end

    def self.[](*pattern)
      glob pattern
    end

    def self.exists?(path)
      File.exist?(path) && File.directory?(path)
    end

    def self.chdir(dir, &blk)
      FileSystem.chdir(dir, &blk)
    end

    def self.chroot(_string)
      fail NotImplementedError
    end

    def self.delete(string)
      _check_for_valid_file(string)
      fail Errno::ENOTEMPTY, string unless FileSystem.find(string).empty?

      FileSystem.delete(string)
    end

    def self.entries(dirname, _opts = {})
      _check_for_valid_file(dirname)

      Dir.new(dirname).map { |file| File.basename(file) }
    end

    def self.foreach(dirname, &_block)
      Dir.open(dirname) { |file| yield file }
    end

    def self.glob(pattern, _flags = 0, &block)
      matches_for_pattern = lambda do |matcher|
        [FileSystem.find(matcher) || []].flatten.map do |e|
          if Dir.pwd.match(/\A\/?\z/) ||
             !e.to_s.match(/\A#{Dir.pwd}\/?/)
            e.to_s
          else
            e.to_s.match(/\A#{Dir.pwd}\/?/).post_match
          end
        end.sort
      end

      if pattern.is_a? Array
        files = pattern.map do |matcher|
          matches_for_pattern.call matcher
        end.flatten
      else
        files = matches_for_pattern.call pattern
      end

      block_given? ? files.each { |file| block.call(file) } : files
    end

    if RUBY_VERSION >= '1.9'
      def self.home(user = nil)
        RealDir.home(user)
      end
    end

    def self.mkdir(string, _integer = 0)
      FileUtils.mkdir(string)
    end

    def self.open(string, &_block)
      if block_given?
        Dir.new(string).each { |file| yield(file) }
      else
        Dir.new(string)
      end
    end

    def self.tmpdir
      '/tmp'
    end

    def self.pwd
      FileSystem.current_dir.to_s
    end

    if RUBY_VERSION >= '2.1'
      # Tmpname module
      module Tmpname # :nodoc:
        module_function

        def tmpdir
          Dir.tmpdir
        end

        def make_tmpname(prefix_suffix, n)
          case prefix_suffix
          when String
            prefix = prefix_suffix
            suffix = ''
          when Array
            prefix = prefix_suffix[0]
            suffix = prefix_suffix[1]
          else
            fail ArgumentError,
                 "unexpected prefix_suffix: #{prefix_suffix.inspect}"
          end
          t = Time.now.strftime('%Y%m%d')
          path = "#{prefix}#{t}-#{$PID}-#{rand(0x100000000).to_s(36)}"
          path << "-#{n}" if n
          path << suffix
        end

        def create(basename, *rest)
          if (opts = Hash.try_convert(rest[-1]))
            opts = opts.dup if rest.pop.equal?(opts)
            max_try = opts.delete(:max_try)
            opts = [opts]
          else
            opts = []
          end
          tmpdir, = *rest
          if $SAFE > 0 && tmpdir.tainted?
            tmpdir = '/tmp'
          else
            tmpdir ||= self.tmpdir
          end
          n = nil
          begin
            path = File.join(tmpdir, make_tmpname(basename, n))
            yield(path, n, *opts)
          rescue Errno::EEXIST
            n ||= 0
            n += 1
            retry if !max_try || n < max_try
            raise "cannot generate temporary name using `#{basename}' " \
              "under `#{tmpdir}'"
          end
          path
        end
      end
    end

    # This code has been borrowed from Rubinius
    def self.mktmpdir(prefix_suffix = nil, tmpdir = nil)
      case prefix_suffix
      when nil
        prefix = 'd'
        suffix = ''
      when String
        prefix = prefix_suffix
        suffix = ''
      when Array
        prefix = prefix_suffix[0]
        suffix = prefix_suffix[1]
      else
        fail ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
      end

      t = Time.now.strftime('%Y%m%d')
      n = nil

      begin
        path = "#{tmpdir}/#{prefix}#{t}-#{$PID}-#{rand(0x100000000).to_s(36)}"
        path << "-#{n}" if n
        path << suffix
        mkdir(path, 0700)
      rescue Errno::EEXIST
        n ||= 0
        n += 1
        retry
      end

      if block_given?
        begin
          yield path
        ensure
          require 'fileutils'
          # This here was using FileUtils.remove_entry_secure instead of just
          # .rm_r. However, the security concerns that apply to
          # .rm_r/.remove_entry_secure shouldn't apply to a test fake
          # filesystem. :^)
          FileUtils.rm_r path
        end
      else
        path
      end
    end

    class << self
      alias_method :getwd, :pwd
      alias_method :rmdir, :delete
      alias_method :unlink, :delete
      alias_method :exist?, :exists?
    end
  end
end
