# frozen_string_literal: true

require 'jekyll/brotli/config'
require 'brotli'

module Jekyll
  ##
  # The main namespace for +Jekyll::Brotli+. Includes the +Compressor+ module
  # which is used to map over files, either using an instance of +Jekyll::Site+
  # or a directory path, and compress them using Brotli.
  module Brotli
    ##
    # The module that does the compressing using Brotli.
    module Compressor
      ##
      # Takes an instance of +Jekyll::Site+ and maps over the site files,
      # compressing them in the destination directory.
      # @example
      #     site = Jekyll::Site.new(site_config)
      #     Jekyll::Brotli::Compressor.compress_site(site)
      #
      # @param site [Jekyll::Site] A Jekyll::Site object that has generated its
      #   site files ready for compression.
      #
      # @return void
      def self.compress_site(site)
        site.each_site_file do |file|
          next unless regenerate? file, site

          compress_file(
            file.destination(site.dest),
            compressable_extensions(site)
          )
        end
      end

      ##
      # Takes a directory path and maps over the files within compressing them
      # in place.
      #
      # @example
      #     Jekyll::Brotli::Compressor.compress_directory("~/blog/_site", site)
      #
      # @param dir [Pathname, String] The path to a directory of files ready for
      #   compression.
      # @param site [Jekyll::Site] An instance of the `Jekyll::Site` used for
      #   config.
      #
      # @return void
      def self.compress_directory(dir, site)
        extensions = compressable_extensions(site).join(',')
        files = Dir.glob(dir + "**/*{#{extensions}}")
        files.each { |file| compress_file(file, compressable_extensions(site)) }
      end

      ##
      # Takes a file name and an array of extensions. If the file name extension
      # matches one of the extensions in the array then the file is loaded and
      # compressed using Brotli, outputting the compressed file under the name
      # of the original file with an extra .br extension.
      #
      # @example
      #     Jekyll::Brotli::Compressor.compress_file("~/blog/_site/index.html")
      #
      # @param file_name [String] The file name of the file we want to compress
      # @param extensions [Array<String>] The extensions of files that will be
      #    compressed.
      #
      # @return void
      def self.compress_file(file_name, extensions)
        return unless extensions.include?(File.extname(file_name))
        compressed = compressed(file_name)
        contents = ::Brotli.deflate(File.read(file_name), quality: 11)

        Jekyll.logger.debug "Brotli: #{compressed}"

        File.open(compressed, "w+") do |file|
          file << contents
        end
        File.utime(File.atime(file_name), File.mtime(file_name), compressed)
      end

      private

      def self.compressed(file_name)
        "#{file_name}.br"
      end

      def self.compressable_extensions(site)
        site.config['brotli'] && site.config['brotli']['extensions'] || Jekyll::Brotli::DEFAULT_CONFIG['extensions']
      end

      # Compresses the file if the site is built incrementally and the
      # source was modified or the compressed file doesn't exist
      #
      # We access the cache directly because Jekyll doesn't expect us to
      # ask twice and always responds false to regenerate?
      #
      # @see jekyll/regenerator.rb
      def self.regenerate?(file, site)
        source_path = if file.is_a? Page
            site.in_source_dir(file.relative_path)
          else
            file.path
          end

        file_name = compressed(file.destination(site.dest))

        site.regenerator.cache[source_path] || !File.exist?(file_name)
      end
    end
  end
end
