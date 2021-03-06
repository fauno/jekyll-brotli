# frozen_string_literal: true

require 'jekyll/brotli/version'
require 'jekyll/brotli/config'
require 'jekyll/brotli/compressor'
require 'pathname'

module Jekyll
  module Brotli
  end
end

Jekyll::Hooks.register :site, :after_init do |site|
  config = site.config['brotli'] || {}
  site.config['brotli'] = Jekyll::Brotli::DEFAULT_CONFIG.merge(config) || {}
end

Jekyll::Hooks.register :site, :post_write do |site|
  Jekyll::Brotli::Compressor.compress_site(site) if Jekyll.env == 'production'
end

Jekyll::Hooks.register :clean, :on_obsolete do |obsolete|
  obsolete.delete_if do |path|
    path.end_with? '.br'
  end
end

begin
  require 'jekyll-assets'

  Jekyll::Assets::Hook.register :env, :after_write do |env|
    if Jekyll.env == 'production'
      path = Pathname.new("#{env.jekyll.config['destination']}#{env.prefix_url}")
      Jekyll::Brotli::Compressor.compress_directory(path, env.jekyll)
    end
  end
rescue LoadError
  # The Jekyll site doesn't use Jekyll::Assets, so no need to compress those
  # files.
end
