#!/usr/bin/env ruby

require 'fileutils'
require 'tempfile'

class HeaderFixer
  @organization
  @project_name = ''

  def initialize organization
    @organization = organization
  end

  def generate_header filename, creator_name, creation_date, project_name
    name = creator_name || (puts 'Generating header. What should the name be?'; gets.chomp)
    if creation_date
      date = creation_date
    else
      puts 'Use today\'s date? (y/n)'
      gets
      if $_[0] != 'y'
        puts 'Enter the date: (DD/MM/YYYY is preferred)'
        date = gets.chomp
      else
        date = Time.now.strftime('%d/%m/%Y')
      end
    end
    year = Time.now.strftime('%Y')

    "//\n//  #{filename}\n//  #{project_name}\n//\n//  Created by #{name} on #{date}.\n//  Copyright © #{year} #{@organization}. All rights reserved.\n//"
  end

  def fix_headers directory, project_name
    puts "Directory: #{directory}"
    subdirs = Dir.glob("#{directory}*/")
    recursive = !project_name.nil?
    unless project_name
      puts 'What is the project name for this directory?'
      project_name = gets.chomp
      unless subdirs.empty?
        puts "Apply the same project name recursively to #{subdirs.count} subdirector#{subdirs.count > 1 ? 'ies' : 'y'}? (y/n)"
        recursive = gets.chomp[0] == 'y'
      end
    end
    Dir.glob("#{directory}*.swift") do |swift_file|
      puts "Fixing #{swift_file}"
      t_file = Tempfile.new('temporary_temp.txt')
      just_started = true
      header_generated = false
      just_generated = false
      header_end = 6
      File.open(swift_file, 'r').each_line.each_with_index do |line, index|
        (header_end += 1; next) if line[0] == '\n' and just_started
        just_started = false
        if index <= header_end
          if !header_generated
            if line =~ /\/\/\s+Cr.*by.*on.*/
              matches = line.match(/\/\/\s+Cr.*by (?<name>.*(?= on)).*(?<date>(?<=on ).*(?=.))/)
              t_file.puts generate_header(File.basename(swift_file), matches[:name], matches[:date], project_name)
              header_generated = true
              just_generated = true
              next
            elsif index == header_end or line[0..1] != '//'
              puts "Header missing in file #{swift_file}."
              t_file.puts generate_header(File.basename(swift_file), nil, nil, project_name)
              header_generated = true
              just_generated = true
            elsif line[0..1] == '//'
              next
            end
          elsif line[0..1] == '//'
            next
          end
        end
        if line != "\n" and just_generated
          t_file.puts "\n"
        end
        t_file.puts line
        just_generated = false
      end
      FileUtils.mv(t_file.path, swift_file)
      t_file.close
    end

    project_name = recursive ? project_name : nil
    subdirs.each do |dir|
      fix_headers dir, project_name
    end
  end
end

directory = ARGV[0] || Dir.pwd
directory << '/' unless directory[-1] == '/'
raise 'Given path is not a valid directory.' unless File.directory?(directory)
organization = ARGV[1] || (puts 'What organization is this?'; gets.chomp)
fixer = HeaderFixer.new organization
fixer.fix_headers directory, nil