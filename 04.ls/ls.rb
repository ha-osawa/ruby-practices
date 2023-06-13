#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'etc'

OUTPUT_COLUMN_NUMBER = 3

FILE_TYPES = {
  'directory' => 'd',
  'file' => '-',
  'link' => 'l',
  'characterSpecial' => 'c',
  'blockSpecial' => 'b',
  'fifo' => 'p',
  'socket' => 's'
}

PERMISSIONS = {
  '0' => '---',
  '1' => '--x',
  '2' => '-w-',
  '3' => '-wx',
  '4' => 'r--',
  '5' => 'r-x',
  '6' => 'rw-',
  '7' => 'rwx'
}

def main
  files, option, max_filename_length, files_status, total_block = make_files
  output(files, option, max_filename_length, files_status, total_block)
end

def output(files, option, max_filename_length, files_status, total_block)
  if option[:l]
    output_files_with_status(files, files_status, total_block)
  else
    output_files(files, max_filename_length)
  end
end

def make_files
  option = parse_option
  files = create_file_list(make_absolute_path).compact.sort
  if option[:l]
    files_stat = create_files_stat(files)
    total_block = calc_total_block(files_stat)
    files_status = make_file_status(files_stat, generate_max_length(files_stat))
    [files, option, nil, files_status, total_block]
  else
    two_dimensional_files = make_two_dimensional_array(align_files(files))
    max_filename_length = generate_max_filename_length(two_dimensional_files)
    transposed_files = two_dimensional_files.transpose
    [transposed_files, option, max_filename_length, nil, nil]
  end
end

def parse_option
  option = {}
  opt = OptionParser.new
  opt.on('-l')
  opt.parse!(ARGV, into: option)
  option
end

def make_absolute_path
  File.expand_path(ARGV[0] || '.')
end

def create_file_list(absolute_path)
  Dir.chdir(absolute_path)
  Dir.glob('*').map.to_a
end

def align_files(sorted_files)
  sorted_files.push(' ') until (sorted_files.length % OUTPUT_COLUMN_NUMBER).zero?
  sorted_files
end

def make_two_dimensional_array(aligned_files)
  aligned_files.each_slice(aligned_files.length / OUTPUT_COLUMN_NUMBER).to_a
end

def generate_max_filename_length(two_dimensional_files)
  two_dimensional_files.flatten.map(&:length).max
end

def count_fullwidth_character(file)
  file.chars.count { |char| char.bytesize == 3 }
end

def create_files_stat(files)
  files.map { |file| File.stat(file) }
end

def calc_total_block(files_stat)
  files_stat.map(&:blocks).sum
end

def convert_permission(permission)
  PERMISSIONS[permission]
end

def generate_permission(file_stat)
  converted_permission = file_stat.mode.to_s(8).slice(-3..-1).chars.map { |permission| convert_permission(permission) }
  converted_permission.inject { |result, permission| result + permission }
end

def convert_file_type(ftype)
  FILE_TYPES[ftype]
end

def generate_max_length(files_stat)
  max_length = {}
  max_length[:nlink] = files_stat.map { |file_stat| file_stat.nlink.to_s.length }.max
  max_length[:user_name] = files_stat.map { |file_stat| Etc.getpwuid(file_stat.uid).name.length }.max
  max_length[:group_name] = files_stat.map { |file_stat| Etc.getgrgid(file_stat.gid).name.length }.max
  max_length[:file_size] = files_stat.map { |file_stat| file_stat.size.to_s.length }.max
  max_length
end

def make_file_status(files_stat, max_length)
  files_stat.map do |file_stat|
    convert_file_type(file_stat.ftype) +
      generate_permission(file_stat).ljust(11) <<
      "#{file_stat.nlink.to_s.rjust(max_length[:nlink])} " <<
      Etc.getpwuid(file_stat.uid).name.ljust(max_length[:user_name] + 2) <<
      Etc.getgrgid(file_stat.gid).name.ljust(max_length[:group_name] + 2) <<
      "#{file_stat.size.to_s.rjust(max_length[:file_size])} " \
      "#{file_stat.mtime.strftime('%_m %_d %H:%M')} "
  end
end

def output_files_with_status(files, files_status, total_block)
  puts "total #{total_block}"
  files_status.each_with_index do |files_with_status, files_index|
    puts "#{files_with_status}#{files[files_index]}"
  end
end

def output_files(output_files, max_file_length)
  output_files.each do |files|
    files.each do |file|
      print file.ljust((max_file_length - count_fullwidth_character(file)) + 2)
    end
    print "\n"
  end
end

main
