require 'date'

module TomlRB
  class Dumper
    attr_reader :toml_str

    def initialize(hash, options = {})
      @toml_str = ''
      @prefer_multiline_strings = options[:prefer_multiline_strings]
      @sort_hash_keys = options.fetch(:sort_hash_keys, true)

      visit(hash, [])
    end

    private

    def visit(hash, prefix, extra_brackets = false)
      simple_pairs, nested_pairs, table_array_pairs = sort_pairs hash

      if prefix.any? && (simple_pairs.any? || hash.empty?)
        print_prefix prefix, extra_brackets
      end

      dump_pairs simple_pairs, nested_pairs, table_array_pairs, prefix
    end

    def sort_pairs(hash)
      nested_pairs = []
      simple_pairs = []
      table_array_pairs = []

      ordered_keys = sort_hash_keys? ? hash.keys.sort : hash.keys

      ordered_keys.each do |key|
        val = hash[key]
        element = [key, val]

        if val.is_a? Hash
          nested_pairs << element
        elsif val.is_a?(Array) && val.first.is_a?(Hash)
          table_array_pairs << element
        else
          simple_pairs << element
        end
      end

      [simple_pairs, nested_pairs, table_array_pairs]
    end

    def dump_pairs(simple, nested, table_array, prefix = [])
      # First add simple pairs, under the prefix
      dump_simple_pairs simple
      dump_nested_pairs nested, prefix
      dump_table_array_pairs table_array, prefix
    end

    def dump_simple_pairs(simple_pairs)
      simple_pairs.each do |key, val|
        key = quote_key(key) unless bare_key? key
        @toml_str << "#{key} = #{to_toml(val)}\n"
      end
    end

    def dump_nested_pairs(nested_pairs, prefix)
      nested_pairs.each do |key, val|
        key = quote_key(key) unless bare_key? key

        visit val, prefix + [key], false
      end
    end

    def dump_table_array_pairs(table_array_pairs, prefix)
      table_array_pairs.each do |key, val|
        key = quote_key(key) unless bare_key? key
        aux_prefix = prefix + [key]

        val.each do |child|
          print_prefix aux_prefix, true
          args = sort_pairs(child) << aux_prefix

          dump_pairs(*args)
        end
      end
    end

    def print_prefix(prefix, extra_brackets = false)
      new_prefix = prefix.join('.')
      new_prefix = '[' + new_prefix + ']' if extra_brackets

      @toml_str += "[" + new_prefix + "]\n"
    end

    def to_toml(obj)
      if obj.is_a?(Time) || obj.is_a?(DateTime)
        obj.strftime('%Y-%m-%dT%H:%M:%SZ')
      elsif obj.is_a?(Date)
        obj.strftime('%Y-%m-%d')
      elsif obj.is_a? Regexp
        obj.inspect.inspect
      elsif obj.is_a? String
        if prefer_multiline_strings? && obj.include?("\n")
          # Newlines and " are special here.  It's safer to split on
          # both and work on the remaining fragments than to use
          # obj.inspect.gsub(), because after #inspect, it's hard to
          # find backslash+" or backslash+n without also finding
          # backslash+backslash+" etc, you end up needing a full parse.

          lines = obj.split("\n", -1).map do |line|
            line.split('"', -1).map do |fragment|
              fragment.inspect.gsub(/\\(#[$@{])/, '\1')[1..-2]
            end.join('"')
          end

          # Escape any embedded occurances of """ as ""\".
          bookend = '"""'
          "#{bookend}\n#{lines.join("\n").gsub(bookend, '""\\"')}#{bookend}"
        else
          obj.inspect.gsub(/\\(#[$@{])/, '\1')
        end
      else
        obj.inspect
      end
    end

    def bare_key?(key)
      !!key.to_s.match(/^[a-zA-Z0-9_-]*$/)
    end

    def quote_key(key)
      '"' + key.gsub('"', '\\"') + '"'
    end

    def prefer_multiline_strings?
      !!@prefer_multiline_strings
    end

    def sort_hash_keys?
      !!@sort_hash_keys
    end
  end
end
