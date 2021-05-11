require_relative 'helper'
require 'date'

class DumperTest < Minitest::Test
  def test_dump_empty
    dumped = TomlRB.dump({})
    assert_equal('', dumped)
  end

  def test_dump_types
    dumped = TomlRB.dump(string: 'TomlRB "dump"')
    assert_equal("string = \"TomlRB \\\"dump\\\"\"\n", dumped)

    dumped = TomlRB.dump(float: -13.24)
    assert_equal("float = -13.24\n", dumped)

    dumped = TomlRB.dump(int: 1234)
    assert_equal("int = 1234\n", dumped)

    dumped = TomlRB.dump(true: true)
    assert_equal("true = true\n", dumped)

    dumped = TomlRB.dump(false: false)
    assert_equal("false = false\n", dumped)

    dumped = TomlRB.dump(array: [1, 2, 3])
    assert_equal("array = [1, 2, 3]\n", dumped)

    dumped = TomlRB.dump(array: [[1, 2], %w(weird one)])
    assert_equal("array = [[1, 2], [\"weird\", \"one\"]]\n", dumped)

    dumped = TomlRB.dump(time: Time.utc(1986, 8, 28, 15, 15))
    assert_equal("time = 1986-08-28T15:15:00Z\n", dumped)

    dumped = TomlRB.dump(datetime: DateTime.new(1986, 8, 28, 15, 15))
    assert_equal("datetime = 1986-08-28T15:15:00Z\n", dumped)

    dumped = TomlRB.dump(date: Date.new(1986, 8, 28))
    assert_equal("date = 1986-08-28\n", dumped)

    dumped = TomlRB.dump(regexp: /abc\n*\{/)
    assert_equal("regexp = \"/abc\\\\n*\\\\{/\"\n", dumped)
  end

  def test_dump_nested_attributes
    hash = { nested: { hash: { deep: true } } }
    dumped = TomlRB.dump(hash)
    assert_equal("[nested.hash]\ndeep = true\n", dumped)

    hash[:nested].merge!(other: 12)
    dumped = TomlRB.dump(hash)
    assert_equal("[nested]\nother = 12\n[nested.hash]\ndeep = true\n", dumped)

    hash[:nested].merge!(nest: { again: 'it never ends' })
    dumped = TomlRB.dump(hash)
    toml = <<-EOS.gsub(/^ {6}/, '')
      [nested]
      other = 12
      [nested.hash]
      deep = true
      [nested.nest]
      again = "it never ends"
    EOS

    assert_equal(toml, dumped)

    hash = { non: { 'bare."keys"' => { "works" => true } } }
    dumped = TomlRB.dump(hash)
    assert_equal("[non.\"bare.\\\"keys\\\"\"]\nworks = true\n", dumped)

    hash = { hola: [{ chau: 4 }, { chau: 3 }] }
    dumped = TomlRB.dump(hash)
    assert_equal("[[hola]]\nchau = 4\n[[hola]]\nchau = 3\n", dumped)
  end

  def test_sorting_of_hash_keys_in_dump
    hash_ab = { a: 1, b: 2 }
    hash_ba = { b: 2, a: 1 }

    # Check assumption that Hash order is preserved.
    assert_equal %i[a b], hash_ab.keys
    assert_equal %i[b a], hash_ba.keys

    # For Hashes whose keys are in order, sort_hash_keys makes no difference.
    assert_equal("a = 1\nb = 2\n", TomlRB.dump(hash_ab))
    assert_equal("a = 1\nb = 2\n", TomlRB.dump(hash_ab, sort_hash_keys: true))
    assert_equal("a = 1\nb = 2\n", TomlRB.dump(hash_ab, sort_hash_keys: false))

    # Passing sort_hash_keys: false preserves the Hash's order.
    assert_equal("a = 1\nb = 2\n", TomlRB.dump(hash_ba))
    assert_equal("a = 1\nb = 2\n", TomlRB.dump(hash_ba, sort_hash_keys: true))
    assert_equal("b = 2\na = 1\n", TomlRB.dump(hash_ba, sort_hash_keys: false))
  end

  def test_print_empty_tables
    hash = { plugins: { cpu: { foo: "bar", baz: 1234 }, disk: {}, io: {} } }
    dumped = TomlRB.dump(hash)
    toml = <<-EOS.gsub(/^ {6}/, '')
      [plugins.cpu]
      baz = 1234
      foo = "bar"
      [plugins.disk]
      [plugins.io]
    EOS

    assert_equal toml, dumped
  end

  def test_dump_array_tables
    hash = { fruit: [{ physical: { color: "red" } }, { physical: { color: "blue" } }] }
    dumped = TomlRB.dump(hash)
    toml = <<-EOS.gsub(/^ {6}/, '')
      [[fruit]]
      [fruit.physical]
      color = "red"
      [[fruit]]
      [fruit.physical]
      color = "blue"
    EOS

    assert_equal toml, dumped
  end

  def test_dump_multiline_string_containing_newlines
    hash = { address: "1 Main St\nSmallville" }
    dumped = TomlRB.dump(hash, prefer_multiline_strings: true)
    toml = <<-EOS.gsub(/^ {6}/, '')
      address = """
      1 Main St
      Smallville"""
    EOS

    assert_equal toml, dumped
  end

  def test_dump_multiline_string_containing_escaped_newlines
    hash = { address: "Line 1\\nStill line 1, since that was a backslash and an 'n', not a newline\nLine 2." }
    dumped = TomlRB.dump(hash, prefer_multiline_strings: true)
    toml = <<-EOS.gsub(/^ {6}/, '')
      address = """
      Line 1\\\\nStill line 1, since that was a backslash and an 'n', not a newline
      Line 2."""
    EOS

    assert_equal toml, dumped
  end

  def test_dump_multiline_string_tables
    hash = { quote: { shakespeare: "To be, or not to be:\n  that is the question" } }

    dumped = TomlRB.dump(hash, prefer_multiline_strings: true)
    toml = <<-EOS.gsub(/^ {6}/, '')
      [quote]
      shakespeare = """
      To be, or not to be:
        that is the question"""
    EOS

    assert_equal toml, dumped
  end

  def test_dump_multiline_string_with_special_chars_tables
    hash = { multiline_string: { with_special_chars: "\tThe quick brown fox\njumps over\\ the lazy dog." } }

    dumped = TomlRB.dump(hash, prefer_multiline_strings: true)
    toml = <<-EOS.gsub(/^ {6}/, '')
      [multiline_string]
      with_special_chars = """
      \\tThe quick brown fox
      jumps over\\\\ the lazy dog."""
    EOS

    assert_equal toml, dumped
  end

  def test_dump_multiline_string_with_single_double_and_triple_quote_marks
    hash = { multiline_string: { single_double_triple_quotes: "\"I like single\"\n\"\"and double\"\"\nand triple \"\"\"quotes in strings\"\"\"" } }

    dumped = TomlRB.dump(hash, prefer_multiline_strings: true)
    toml = <<-EOS.gsub(/^ {6}/, '')
      [multiline_string]
      single_double_triple_quotes = """
      "I like single"
      ""and double""
      and triple ""\\"quotes in strings""\\""""
    EOS

    assert_equal toml, dumped
  end

  def test_dump_interpolation_curly
    hash = { "key" => 'includes #{variable}' }
    dumped = TomlRB.dump(hash)
    assert_equal 'key = "includes #{variable}"' + "\n", dumped
  end

  def test_dump_interpolation_at
    hash = { "key" => 'includes #@variable' }
    dumped = TomlRB.dump(hash)
    assert_equal 'key = "includes #@variable"' + "\n", dumped
  end

  def test_dump_interpolation_dollar
    hash = { "key" => 'includes #$variable' }
    dumped = TomlRB.dump(hash)
    assert_equal 'key = "includes #$variable"' + "\n", dumped
  end
end
