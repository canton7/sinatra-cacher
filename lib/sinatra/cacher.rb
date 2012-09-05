require 'fileutils'
require 'sinatra/base'

module Sinatra
  module Cacher
    VERSION = '0.9.2'

    def self.registered(app)
      app.helpers Helpers
      # Special value :environment means environment is used
      app.set :cache_enabled, :environment
      app.set :cache_enabled_in, :production
      app.set :cache_generate_etags, true
      app.set :cache_path, 'tmp/cache'
      # Internal use only
      app.set :cache_last_tag, nil
      app.set :cache_overwrite, false
    end

    def cache_enabled?
      settings.cache_enabled == true || (settings.cache_enabled == :environment && [*settings.cache_enabled_in].include?(settings.environment))
    end

    def cache_get(path, opts={}, &blk)
      conditions = @conditions.dup
      cache_route('GET', path, opts, &blk)
      @conditions = conditions
      route('HEAD', path, opts, &blk)
    end
    alias_method :get_cache, :cache_get

    def cache_get_tag(tag)
      return nil if !tag
      path = cache_gen_path(tag)
      return nil unless File.file?(path)
      time, content_type, content = File.open(path, 'rb') do |f|
        [f.gets.chomp.to_i, f.gets.chomp, f.read]
      end
      if content_type == 'marshal'
        content = Marshal.load(content)
        content_type = nil
      elsif content_type.empty?
        content_type = nil
      end
      [content, time, content_type]
    end

    def cache_put_tag(tag, content, content_type=nil)
      return unless cache_enabled?
      raise "Cache tag should not end with a slash" if tag.end_with?('/')
      raise "Cache tag should not be empty" if tag.empty?
      unless content.is_a?(String)
        raise "Can't cache a route which doesn't return a string" if content_type
        content = Marshal.dump(content)
        content_type = 'marshal'
      end
      path = cache_gen_path(tag)
      FileUtils.mkdir_p(File.dirname(path))
      time = Time.now.to_i
      # We can get \r\n => \n\n conversion unless we open in binary mode
      File.open(path, 'wb') do |f|
        f.puts(time)
        f.puts(content_type)
        f.print(content)
      end
      time
    end

    def cache_clear(tag='/')
      path = File.join(settings.root, settings.cache_path, tag.to_s)
      # If they gave us e.g. 'path/', make it into a glob. Otherwise add a file extension
      path << (path.end_with?('/') ? '*' : '.html')
      FileUtils.rm_r(Dir.glob(path))
    end

    private

    def cache_gen_path(tag)
       path = File.join(settings.root, settings.cache_path, tag)
       path << '.html' if File.extname(path).empty?
       path
    end

    def cache_route_pre(tag, context)
      # Guess a suitable tag if we're told to
      tag = context.cache_guess_tag(tag)

      # If they gave us a tag upfront, (as an arg to cache_get/etc) see whether we can get it
      if tag
        cache_content, cache_time, content_type = cache_get_tag(File.join('pages', tag))
        if cache_content
          context.etag cache_time if settings.cache_generate_etags
          context.content_type content_type if content_type
          return tag, cache_content
        end
      end
      return tag, nil
    end

    def cache_route_post(ret, tag, context)
      # If ret is an array with the first element :cache_hit, it means we hit the cache
      # This could happen if they call cache_tag
      if ret.is_a?(Array) && ret.first == :cache_hit
        _, cache_content, cache_time, content_type = ret
        context.etag cache_time if settings.cache_generate_etags
        context.content_type content_type if content_type
        return cache_content
      end

      # If we got this far, we didn't hit a cache anywhere
      # Update tag if it was set from cache_tag, and write to the cache
      tag ||= settings.cache_last_tag
      if tag
        tag = context.cache_guess_tag(tag)
        time = cache_put_tag(File.join('pages', tag), ret, context.response['Content-Type'])
        context.etag time if settings.cache_generate_etags
      end
      settings.cache_last_tag = nil
      settings.cache_overwrite = false
      ret
    end

    def cache_route(verb, path, opts={}, &blk)
      tag = opts.delete(:tag)

      unless cache_enabled?
        route(verb, path, opts, &blk)
        return
      end

      method = generate_method :"C#{verb} #{path} #{opts.hash}", &blk

      cache_blk = Proc.new { |context, *args|
        updated_tag, cache_content = cache_route_pre(tag, context)
        next cache_content if cache_content

        ret = catch(:cache_stop){ method.bind(context).call(*args) }

        ret = cache_route_post(ret, updated_tag, context)
        ret
      }

      route(verb, path, opts) do |*bargs|
        cache_blk.call(self, *bargs)
      end
    end

    module Helpers
      # def cache_get_tag(*args); settings.cache_get_tag(*args); end
      # def cache_put_tag(*args); settings.cache_put_tag(*args); end
      def cache_clear(*args); settings.cache_clear(*args); end

      def cache_tag(tag=:auto, opts={})
        return unless settings.cache_enabled?
        cache_overwrite if opts[:overwrite]
        tag = cache_guess_tag(tag)
        unless settings.cache_overwrite
          content = settings.cache_get_tag(File.join('pages', tag))
          throw :cache_stop, content.unshift(:cache_hit) if content
        end
        settings.cache_last_tag = tag
      end

      def cache_overwrite
        settings.cache_overwrite = true
      end

      def cache_guess_tag(tag)
        return (tag ? tag.to_s : nil) unless [true, :auto].include?(tag)
        tag = request.path_info
        tag = File.join(tag, 'index') if tag.empty? || tag.end_with?('/')
        tag
      end

      def cache_block(tag, opts={})
        raise "No block given to cache_block" unless block_given?
        tag = "blocks/#{tag}"
        unless opts[:overwrite]
          content = settings.cache_get_tag(tag)
          return content.first if content
        end
        content = yield
        settings.cache_put_tag(tag, content)
        content
      end

      def cache_fragment(tag, opts={}, &blk)
        raise "You must install sinatra-outputbuffer, require sinatra/outputbuffer, and register Sinatra::OutputBuffer to use cache_fragment" unless respond_to?(:capture_html)
        raise "No block given to cache_fragment" unless block_given?
        tag = "fragments/#{tag}"
        unless opts[:overwrite]
          content, = settings.cache_get_tag(tag)
          return block_is_template?(blk) ? concat_content(content) : content if content
        end
        content = capture_html(&blk)
        settings.cache_put_tag(tag, content)
        block_is_template?(blk) ? concat_content(content) : content
      end

    end
  end

  register Cacher
end
