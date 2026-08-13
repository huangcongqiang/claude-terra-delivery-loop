#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'optparse'
require 'digest'

options = {
  allow: [],
  allow_ignored: [],
  expect: [],
  allow_delete: false,
  allow_empty: false
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: check_delivery_diff.rb --repo PATH [options]'
  opts.on('--repo PATH', 'Git worker repository') { |value| options[:repo] = value }
  opts.on('--base REF', 'Immutable baseline revision (required)') { |value| options[:base] = value }
  opts.on('--allow GLOB', 'Allowed changed path; repeatable') { |value| options[:allow] << value }
  opts.on('--allow-ignored PATH=BASELINE', 'Exact ignored file plus pre-worker SHA-256 or ABSENT; repeatable') do |value|
    options[:allow_ignored] << value
  end
  opts.on('--expect GLOB', 'At least one changed path must match; repeatable') { |value| options[:expect] << value }
  opts.on('--allow-delete', 'Permit deleted paths') { options[:allow_delete] = true }
  opts.on('--allow-empty', 'Permit an empty diff') { options[:allow_empty] = true }
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  warn "[FAIL] #{e.message}"
  warn parser
  exit 2
end

unless options[:repo]
  warn '[FAIL] --repo is required'
  warn parser
  exit 2
end

unless options[:base]
  warn '[FAIL] --base is required and must be the immutable pre-worker revision'
  warn parser
  exit 2
end

if options[:allow].empty?
  warn '[FAIL] at least one --allow path or glob is required'
  warn parser
  exit 2
end

repo = File.expand_path(options[:repo])
unless File.directory?(repo)
  warn "[FAIL] repository directory does not exist: #{repo}"
  exit 2
end

def git(repo, *args)
  stdout, stderr, status = Open3.capture3('git', '-C', repo, *args)
  return stdout if status.success?

  raise "git #{args.join(' ')} failed: #{stderr.strip}"
end

def matches?(path, patterns)
  patterns.any? do |pattern|
    File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
  end
end

def parse_ignored_entries(entries)
  parsed = {}
  entries.each do |entry|
    path, baseline = entry.split('=', 2)
    raise "invalid --allow-ignored entry: #{entry}" if path.nil? || path.empty? || baseline.nil? || baseline.empty?
    raise "--allow-ignored requires an exact relative file path: #{path}" if path.start_with?('/') || path.split('/').include?('..') || path.match?(/[\*?\[\]{}]/)
    raise "invalid ignored baseline for #{path}: #{baseline}" unless baseline == 'ABSENT' || baseline.match?(/\A[0-9a-f]{64}\z/)
    raise "duplicate --allow-ignored path: #{path}" if parsed.key?(path)

    parsed[path] = baseline
  end
  parsed
end

errors = []

begin
  top = git(repo, 'rev-parse', '--show-toplevel').strip
  repo = File.expand_path(top)
  git(repo, 'rev-parse', '--verify', "#{options[:base]}^{commit}")
  ignored_entries = parse_ignored_entries(options[:allow_ignored])
  ignored_entries.each_key do |path|
    _ignored_stdout, _ignored_stderr, ignored_status = Open3.capture3('git', '-C', repo, 'check-ignore', '--no-index', '--', path)
    raise "--allow-ignored path is not ignored: #{path}" unless ignored_status.success?

    absolute = File.expand_path(path, repo)
    raise "--allow-ignored path is not a regular file: #{path}" if File.exist?(absolute) && !File.file?(absolute)
  end

  tracked = git(repo, 'diff', '--no-renames', '--name-only', options[:base], '--').lines.map(&:strip).reject(&:empty?)
  untracked = git(repo, 'ls-files', '--others', '--exclude-standard').lines.map(&:strip).reject(&:empty?)
  ignored_changed = ignored_entries.each_with_object([]) do |(path, baseline), paths|
    absolute = File.expand_path(path, repo)
    current = File.file?(absolute) ? Digest::SHA256.file(absolute).hexdigest : 'ABSENT'
    paths << path unless current == baseline
  end
  changed = (tracked + untracked + ignored_changed).uniq.sort
  deleted = git(repo, 'diff', '--no-renames', '--diff-filter=D', '--name-only', options[:base], '--').lines.map(&:strip).reject(&:empty?).sort

  errors << 'worker produced no filesystem diff' if changed.empty? && !options[:allow_empty]

  unless options[:allow].empty?
    outside = changed.reject { |path| matches?(path, options[:allow]) }
    errors << "out-of-scope paths: #{outside.join(', ')}" unless outside.empty?
  end

  options[:expect].each do |pattern|
    errors << "required changed path missing: #{pattern}" unless changed.any? { |path| matches?(path, [pattern]) }
  end

  errors << "deleted paths require --allow-delete: #{deleted.join(', ')}" if !options[:allow_delete] && !deleted.empty?

  diff_stdout, diff_stderr, diff_status = Open3.capture3('git', '-C', repo, 'diff', '--check', options[:base], '--')
  diff_message = [diff_stdout, diff_stderr].map(&:strip).reject(&:empty?).join(' | ')
  errors << "git diff --check failed: #{diff_message}" unless diff_status.success?

  if errors.empty?
    puts "[PASS] delivery diff base=#{options[:base]} changed=#{changed.size} deleted=#{deleted.size}"
    changed.each { |path| puts "  #{path}" }
    exit 0
  end
rescue StandardError => e
  errors << e.message
end

warn "[FAIL] delivery diff errors=#{errors.size}"
errors.each { |message| warn "  - #{message}" }
exit 1
