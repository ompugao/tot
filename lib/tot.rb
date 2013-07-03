# -*- coding: utf-8 -*-
require "tot/version"
require "thor"
require "readline"
require "fileutils"
require "yaml"
require "time"
require "term/ansicolor"

module Tot
  module Config #{{{
    @@CONFIG_FILE = File.join(ENV['HOME'],'.totrc')
    @@TODO_PATH = nil
    def todo_path
      create unless File.exists?(@@CONFIG_FILE)
      @@TODO_PATH = YAML.load_file(@@CONFIG_FILE)['todo_file'] 
    end

    def create
      path = Readline.readline("Input the path to save tasks >> ",false)
      path += ".yaml" unless [".yaml",".yml"].include?(File.extname(path))
      File.open(@@CONFIG_FILE,'w'){|file| YAML.dump({'todo_file' => path}, file)}
    end
    module_function :todo_path,:create
  end #}}}

  class TodoManager #{{{
    include Enumerable
    def initialize
      load_file
    end
    def load_file
      todo_path = Config.todo_path
      File.open(todo_path,'w'){|file| YAML.dump([],file)} unless File.exists? todo_path
      @tasks = YAML.load_file(todo_path).sort_by{|i| i['date']}
    end

    def dump
      #File.open(Config.todo_path,'w'){|file| file.puts todos.ya2yaml} #YAML.dump(todos, file)}
      # ya2yamlだとhashの順番が変わる
      File.open(Config.todo_path,'w'){|file| YAML.dump(@tasks, file)}
    end

    def add(new_todo)
      @tasks.push new_todo
      dump
    end
    
    def delete(at)
      @tasks = load_file
      @tasks.delete_at(at)
      dump
    end

    def each
      @tasks = load_file
      @tasks.each do |todo|
        yield todo
      end
      self
    end

    def delete_at(at)
      @tasks.delete_at at
    end

    def find_all!(&block)
      @tasks = self.find_all(&block)
    end
    def print_color(with_index = false) #{{{
      @tasks.each_with_index do |todo,idx|
        #https://github.com/flori/term-ansicolor/blob/master/examples/example.rb
        case (Date.parse(todo['date'].to_s) - Date.parse(Time.now.to_s)).to_i
        when -10 .. -1
          print Term::ANSIColor.cyan
        when 0..1
          print Term::ANSIColor.bold, Term::ANSIColor.red
        when 2..3
          print Term::ANSIColor.yellow
        else
          print Term::ANSIColor.white
        end

        puts [("<<#{idx}>>" if with_index),
              todo['date'].strftime("%Y/%m/%d %H:%M"),
              todo['title'],
              ['[',todo['tag'],']'].flatten.join(' ')].join(' ') 
        print Term::ANSIColor.reset
      end
      self
    end #}}}
    #module_function :load_file, :dump, :listup, :add
  end #}}}

  module Utils #{{{
    def datetime_filter(buf) #{{{
      today = DateTime.now
      ret = nil
      case buf
      when /^(今日)/
        ret = today
      when /^(明日|あした|あす)/
        ret = today + 1
      when /^(明後日|あさって)/
        ret = today + 2
      when /^しあさって/
        ret = today + 3
      when /^(日|月|火|水|木|金|土)曜(日)?/
        # 次の○曜日
        date_offset = ([ '日', '月', '火', '水', '木', '金', '土' ].index($1) - today.wday + 7) % 7
        date_offset += 7 if date_offset == 0
        ret = today + date_offset
      when /^([0-9]+\/[0-9]+\/[0-9]+)/# yyyy/mm/dd
        ret = DateTime.parse($1)
      when /^([0-9]+\/[0-9]+)/# mm/dd
        date = DateTime.parse($1)
        # 過去の日付だったら来年にする
        while date < today
          date = date >> 12
        end
        ret = date
      when /^([0-9]+)/# mmddd
        datestr = $1
        case datestr.length
        when 2
          # 12   => 1/2
          datestr = datestr.slice(0..0) + "/" + datestr.slice(1..1)
        when 3
          # 123  => 1/23 ※ 12/3 の可能性もあるけどそうはしない
          datestr = datestr.slice(0..0) + "/" + datestr.slice(1..2)
        when 4
          # 1230 => 12/30
          datestr = datestr.slice(0..1) + "/" + datestr.slice(2..3)
        else
          raise ArgumentError , "不正な値です"
        end
        date = DateTime.parse(datestr)
        # 過去の日付だったら来年にする
        while date < today
          date = date >> 12
        end
        ret = date
      end
      ret
    end #}}}

    module_function :datetime_filter
  end #}}}

  class CLI < Thor
    def initialize(*args)
      super
      @todo_manager = TodoManager.new
    end

    desc 'list' , 'list up your todo'
    method_option :tag, :type => :array
    def list
      if options['tag']
        @todo_manager.find_all! do |todo|
          options[:tag].all?{|i| todo['tag'].include? i}
        end
      end
      @todo_manager.print_color(false)
    end

    desc 'add' , 'add a task'
    def add
      new_todo = {}
      new_todo['title'] = Readline.readline('title> ', true).chomp('\n')
      new_todo['date'] = Time.parse(Utils.datetime_filter(Readline.readline('date> ', true).chomp('\n')).to_s)
      new_todo['tag'] = Readline.readline('tag (separate by space)> ', true)
                          .chomp('\n').split(' ')
      tmpfile = "/tmp/tot.markdown"
      # File.open(tmpfile,"w"){|file|
      #   file.puts "\n\n# This line will be ignored."
      # }
      system([ENV['EDITOR'],tmpfile].join(' '))
      new_todo['text'] = File.readlines(tmpfile).join
      print new_todo['text']
      File.delete tmpfile
      @todo_manager.add new_todo
    end

    desc 'delete', 'delete a task'
    def delete
      @todo_manager.print_color(true)
      @todo_manager.delete_at Readline.readline('Which Task?> ',false).chomp('\n').to_i
      @todo_manager.dump
    end

    desc 'show TITLE', <<-EOF
show the detail of a task.
TITLE does not need to be complete.
EOF
    def show(title)
      reg = Regexp.new(title,Regexp::IGNORECASE)
      todos = @todo_manager.find_all{|item| reg.match(item['title'])}
      if todos.size == 0
        puts 'No matched task.'
      elsif todos.size > 1
        puts 'Several tasks matched.'
      else
        todo = todos[0]
        puts 'Title: ' + todo['title']
        puts 'Date:  ' + todo['date'].strftime("%Y/%m/%d %H:%M")
        puts
        print todo['text']
      end
      
    end

    desc 'edit TITLE', 'edit a task'
    method_options :text => :boolean, :title => :boolean, :date => :boolean, :tag => :boolean
    def edit(title)
      reg = Regexp.new(title,Regexp::IGNORECASE)
      todos = @todo_manager.find_all{|item| reg.match(item['title'])}
      if todos.size == 0
        puts 'No matched task.'
      elsif todos.size > 1
        puts todos.size.to_s + ' tasks matched.'
      else
        todo = todos[0]
        old_title = todo['title']
        if options['title']
          todo['title'] = Readline.readline('New Title> ').chomp('\n')
        elsif options['date']
          todo['date'] = Time.parse(Utils.datetime_filter(Readline.readline('date> ', true).chomp('\n')).to_s)
        elsif options['tag']
          todo['tag'] = Readline.readline("tag (old_value: #{todo['tag'].join(' ')})> ", true)
                          .chomp('\n').split(' ')
        else
          tmpfile = "/tmp/tot.markdown"
          File.open(tmpfile,'w'){|file| file.write todo['text']}
          system([ENV['EDITOR'],tmpfile].join(' '))
          todo['text'] = File.readlines(tmpfile).join
          File.delete tmpfile
        end

        puts 'Title: ' + todo['title']
        puts 'Date:  ' + todo['date'].strftime("%Y/%m/%d %H:%M")
        puts 'Tags:  ' + todo['tag'].to_s
        puts
        print todo['text']
        @todo_manager.delete_at(@todo_manager.find_index{|obj| obj['title'] == old_title})
        @todo_manager.add todo
      end
      
    end
  end
end

