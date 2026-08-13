#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class CheckDeliveryDiffTest < Minitest::Test
  SCRIPT = File.expand_path('check_delivery_diff.rb', __dir__)

  def setup
    @repo = Dir.mktmpdir('delivery-diff-')
    run!('git', 'init', '-q', @repo)
    run!('git', '-C', @repo, 'config', 'user.email', 'test@example.invalid')
    run!('git', '-C', @repo, 'config', 'user.name', 'Delivery Diff Test')
    File.write(File.join(@repo, '.gitignore'), "local.env\nignored-dir/\n")
    File.write(File.join(@repo, 'tracked.txt'), "baseline\n")
    run!('git', '-C', @repo, 'add', '.gitignore', 'tracked.txt')
    run!('git', '-C', @repo, 'commit', '-qm', 'baseline')
    @base = run!('git', '-C', @repo, 'rev-parse', 'HEAD').strip
  end

  def teardown
    FileUtils.remove_entry(@repo) if @repo && File.exist?(@repo)
  end

  def test_detects_authorized_ignored_file_change
    ignored = File.join(@repo, 'local.env')
    File.write(ignored, "before\n")
    baseline = Digest::SHA256.file(ignored).hexdigest
    File.write(ignored, "after\n")

    stdout, stderr, status = checker(
      '--allow', 'local.env',
      '--expect', 'local.env',
      '--allow-ignored', "local.env=#{baseline}"
    )

    assert status.success?, [stdout, stderr].join("\n")
    assert_includes stdout, 'local.env'
  end

  def test_rejects_ignored_directory_manifest
    FileUtils.mkdir_p(File.join(@repo, 'ignored-dir'))
    _stdout, stderr, status = checker(
      '--allow', 'ignored-dir',
      '--allow-ignored', 'ignored-dir=ABSENT'
    )

    refute status.success?
    assert_includes stderr, '--allow-ignored path is not a regular file'
  end

  def test_rejects_non_ignored_manifest_path
    _stdout, stderr, status = checker(
      '--allow', 'tracked.txt',
      '--allow-ignored', 'tracked.txt=ABSENT'
    )

    refute status.success?
    assert_includes stderr, '--allow-ignored path is not ignored'
  end

  private

  def checker(*args)
    Open3.capture3('ruby', SCRIPT, '--repo', @repo, '--base', @base, *args)
  end

  def run!(*command)
    stdout, stderr, status = Open3.capture3(*command)
    raise "#{command.join(' ')} failed: #{stderr}" unless status.success?

    stdout
  end
end
